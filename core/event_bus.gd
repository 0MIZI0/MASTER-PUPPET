extends Node


signal pin_placed(pin_type: int, world_pos: Vector2)
signal pin_committed(pin_type: int, world_pos: Vector2)
signal pin_cleared(pin_type: int)
signal pin_type_selected(pin_type: int)
signal pin_commit_requested(pin_type: int, world_pos: Vector2)  ## 판정 생략 강제 명령 (RECALL 등)


signal bullet_time_requested(source: StringName, active: bool)
signal bullet_time_toggled(active: bool)


signal counter_proposal_raised(leader: Node2D, original_pos: Vector2, proposed_pos: Vector2, original_type: int)
signal counter_proposal_decided(accepted: bool)
signal counter_proposal_resolved(accepted: bool)
signal squad_buff_applied(attack_mult: float, duration: float)


signal hero_state_changed(hero: Node2D, stat: StringName, value: float)
signal unit_died(unit: Node2D)


# 마스터 스킬
signal master_skill_requested(index: int)
signal master_skill_cast(skill: MasterSkillData)
signal master_skills_ready(skills: Array[MasterSkillData])
signal master_state_changed(mana: float, max_mana: float, cooldowns: PackedFloat32Array)


# 미션
signal missions_available(missions: Array[MissionData], current_index: int)
signal mission_restart_requested(index: int)
signal mission_started(title: String, briefing: String)
signal mission_progress(text: String)
signal mission_ended(victory: bool, reason: String)
