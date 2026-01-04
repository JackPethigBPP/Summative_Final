
import os
import pytest
from app import create_app, db

@pytest.fixture()
def client(tmp_path):
    os.environ['DATABASE_URL'] = f"sqlite:///{tmp_path}/test.db"  # use sqlite for tests
    app = create_app()
    app.config.update({
        'TESTING': True
    })
    with app.test_client() as client:
        yield client

def test_create_and_list_order(client):
    # create
    r = client.post('/api/orders', json={
        'customer_name': 'Test Customer',
        'drink': 'Cappuccino',
        'size': 'Medium'
    })
    assert r.status_code == 201
    order = r.get_json()
    assert order['customer_name'] == 'Test Customer'

    # list
    r2 = client.get('/api/orders')
    assert r2.status_code == 200
    data = r2.get_json()
    assert len(data) >= 1

    # update
    r3 = client.patch(f"/api/orders/{order['id']}", json={'status': 'IN_PROGRESS'})
    assert r3.status_code == 200
    updated = r3.get_json()
    assert updated['status'] == 'IN_PROGRESS'
