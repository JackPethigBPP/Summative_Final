
from datetime import datetime
from enum import Enum
from . import db

class OrderStatus(str, Enum):
    NEW = "NEW"
    IN_PROGRESS = "IN_PROGRESS"
    DONE = "DONE"

class Order(db.Model):
    __tablename__ = "orders"
    id = db.Column(db.Integer, primary_key=True)
    customer_name = db.Column(db.String(120), nullable=False)
    drink = db.Column(db.String(120), nullable=False)
    size = db.Column(db.String(20), nullable=False)
    notes = db.Column(db.Text, nullable=True)
    status = db.Column(db.Enum(OrderStatus), default=OrderStatus.NEW, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)

    def to_dict(self):
        return {
            "id": self.id,
            "customer_name": self.customer_name,
            "drink": self.drink,
            "size": self.size,
            "notes": self.notes,
            "status": self.status.value if hasattr(self.status, 'value') else str(self.status),
            "created_at": self.created_at.isoformat(),
        }
