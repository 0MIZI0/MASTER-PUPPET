extends Node
## 생존 유닛 레지스트리 (Autoload: UnitRegistry).
## get_nodes_in_group()은 호출마다 Array 할당 → 핫패스는 이 캐시 배열을 사용.
## 반환 배열은 읽기 전용으로 취급 (순회 중 수정 금지).

var allies: Array[UnitBase] = []
var enemies: Array[UnitBase] = []
var leader: UnitBase


func register(u: UnitBase) -> void:
	var list: Array[UnitBase] = of_faction(u.faction)
	if not list.has(u):
		list.append(u)
	if u.is_leader:
		leader = u


func unregister(u: UnitBase) -> void:
	allies.erase(u)
	enemies.erase(u)
	if leader == u:
		leader = null


func of_faction(f: UnitBase.Faction) -> Array[UnitBase]:
	return allies if f == UnitBase.Faction.ALLY else enemies


func opponents_of(f: UnitBase.Faction) -> Array[UnitBase]:
	return enemies if f == UnitBase.Faction.ALLY else allies
