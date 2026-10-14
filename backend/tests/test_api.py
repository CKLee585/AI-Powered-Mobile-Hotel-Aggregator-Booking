from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_reports_mock_mode_and_security_headers() -> None:
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["status"] == "ok"
    assert response.json()["data_mode"] == "mock"
    assert response.headers["x-content-type-options"] == "nosniff"
    assert response.headers["cache-control"] == "no-store"
    assert response.headers["x-request-id"]


def test_swagger_ui_is_available_in_development() -> None:
    response = client.get("/docs")

    assert response.status_code == 200
    assert "Swagger UI" in response.text


def test_text_search_returns_ranked_top_three_candidates() -> None:
    response = client.post(
        "/api/v1/search/text",
        json={"query": "Sunway", "required_tags": [], "limit": 3},
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["mode"] == "mock"
    assert payload["request_type"] == "text"
    assert len(payload["candidates"]) == 3
    assert payload["candidates"][0]["id"] == "sunway-resort"
    assert payload["candidates"][0]["match_confidence"] == 0.95


def test_text_search_tolerates_a_misspelled_hotel_name() -> None:
    response = client.post(
        "/api/v1/search/text",
        json={"query": "Sunwey Resor Hotel"},
    )

    assert response.status_code == 200
    first_candidate = response.json()["candidates"][0]
    assert first_candidate["id"] == "sunway-resort"
    assert first_candidate["match_confidence"] >= 0.8


def test_required_tags_act_as_strict_filters() -> None:
    response = client.post(
        "/api/v1/search/text",
        json={
            "query": "Kuala Lumpur",
            "required_tags": ["budget_friendly", "family_friendly"],
        },
    )

    assert response.status_code == 200
    candidates = response.json()["candidates"]
    assert [candidate["id"] for candidate in candidates] == ["aloft-kl"]


def test_invalid_query_and_unknown_fields_are_rejected() -> None:
    invalid_query = client.post(
        "/api/v1/search/text",
        json={"query": "!!"},
    )
    unknown_field = client.post(
        "/api/v1/search/text",
        json={"query": "Sunway", "api_key": "must-not-be-accepted"},
    )

    assert invalid_query.status_code == 422
    assert unknown_field.status_code == 422


def test_visual_candidate_contract_returns_three_ranked_matches() -> None:
    response = client.post(
        "/api/v1/candidates",
        json={
            "source": "camera",
            "image_reference": "hotel-signboard.jpg",
            "visual_hints": ["Sunway"],
        },
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["request_type"] == "camera"
    assert len(payload["candidates"]) == 3
    assert payload["candidates"][0]["id"] == "sunway-resort"
    assert payload["candidates"][0]["match_confidence"] == 0.96


def test_visual_candidate_contract_rejects_device_paths() -> None:
    response = client.post(
        "/api/v1/candidates",
        json={
            "source": "gallery",
            "image_reference": "/private/user/photos/hotel.jpg",
        },
    )

    assert response.status_code == 422


def test_provider_offer_contract_is_mock_and_traceable() -> None:
    response = client.get("/api/v1/provider-offers/sunway-resort")

    assert response.status_code == 200
    offers = response.json()
    assert len(offers) == 3
    assert all(offer["is_mock"] for offer in offers)
    assert all(offer["currency"] == "MYR" for offer in offers)
    assert all(offer["retrieved_at"] for offer in offers)


def test_unknown_hotel_offer_request_returns_not_found() -> None:
    response = client.get("/api/v1/provider-offers/not-a-hotel")

    assert response.status_code == 404
