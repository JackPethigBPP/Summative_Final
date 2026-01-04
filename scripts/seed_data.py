
from app import create_app, db
from app.models import Order

orders = [
    dict(customer_name="Alex", drink="Latte", size="Large", notes="Oat milk"),
    dict(customer_name="Sam", drink="Espresso", size="Small", notes="Double shot"),
    dict(customer_name="Kim", drink="Mocha", size="Medium", notes="Less sugar"),
]

if __name__ == '__main__':
    app = create_app()
    with app.app_context():
        for o in orders:
            db.session.add(Order(**o))
        db.session.commit()
        print("Seeded sample orders.")
