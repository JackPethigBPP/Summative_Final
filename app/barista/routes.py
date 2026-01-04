
from flask import Blueprint, render_template, request, redirect, url_for
from .. import db
from ..models import Order, OrderStatus

barista_bp = Blueprint('barista', __name__)

@barista_bp.route('/barista', methods=['GET'])
def barista():
    # Show queue prioritized by status and created time
    queue = Order.query.filter(Order.status != OrderStatus.DONE).order_by(Order.status.asc(), Order.created_at.asc()).all()
    done = Order.query.filter(Order.status == OrderStatus.DONE).order_by(Order.created_at.desc()).limit(20).all()
    return render_template('barista.html', queue=queue, done=done)

@barista_bp.route('/barista/update/<int:order_id>/<string:new_status>', methods=['POST'])
def update(order_id, new_status):
    order = Order.query.get_or_404(order_id)
    if new_status in {s.value for s in OrderStatus}:
        order.status = OrderStatus(new_status)
        db.session.commit()
    return redirect(url_for('barista.barista'))
