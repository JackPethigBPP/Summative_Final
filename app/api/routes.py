
from flask import Blueprint, request, jsonify
from .. import db
from ..models import Order, OrderStatus

api_bp = Blueprint('api', __name__)

@api_bp.get('/orders')
def list_orders():
    status = request.args.get('status')
    query = Order.query
    if status:
        if status not in {s.value for s in OrderStatus}:
            return jsonify({"error": "invalid status"}), 400
        query = query.filter(Order.status == OrderStatus(status))
    orders = [o.to_dict() for o in query.order_by(Order.created_at.desc()).all()]
    return jsonify(orders)

@api_bp.post('/orders')
def create_order():
    data = request.get_json(force=True, silent=True) or {}
    customer_name = data.get('customer_name')
    drink = data.get('drink')
    size = data.get('size')
    notes = data.get('notes')
    if not customer_name or not drink or not size:
        return jsonify({"error": "customer_name, drink, size are required"}), 400
    order = Order(customer_name=customer_name, drink=drink, size=size, notes=notes)
    db.session.add(order)
    db.session.commit()
    return jsonify(order.to_dict()), 201

@api_bp.patch('/orders/<int:order_id>')
def update_order(order_id):
    order = Order.query.get_or_404(order_id)
    data = request.get_json(force=True, silent=True) or {}
    status = data.get('status')
    if status and status in {s.value for s in OrderStatus}:
        order.status = OrderStatus(status)
        db.session.commit()
    else:
        return jsonify({"error": "invalid status"}), 400
    return jsonify(order.to_dict())
