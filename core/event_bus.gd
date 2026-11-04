extends Node


signal pin_placed(pin_type: int, world_pos: Vector2)
signal pin_committed(pin_type: int, world_pos: Vector2)
signal pin_cleared(pin_type: int)
signal pin_type_selected(pin_type: int)


signal bullet_time_requested(source: StringName, active: bool)
signal bullet_time_toggled(active: bool)


signal counter_proposal_raised(leader: Node2D, original_pos: Vector2, proposed_pos: Vector2, original_type: int)
signal counter_proposal_decided(accepted: bool)
signal counter_proposal_resolved(accepted: bool)
signal squad_buff_applied(attack_mult: float, duration: float)


signal hero_state_changed(hero: Node2D, stat: StringName, value: float)
signal unit_died(unit: Node2D)
