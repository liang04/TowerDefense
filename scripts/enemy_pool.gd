## 敌人对象池（挂在主场景的 Enemies 容器节点上）
## 与子弹池同理：避免敌人频繁 instantiate/queue_free 带来的节点构建与 GC 停顿。
## 每个敌人还会构建 AnimatedSprite2D、阴影、碰撞盒，构建成本比子弹更高，更值得复用。
##
## 按 enemy_type 分桶——精灵/阴影/碰撞盒在 Enemy._ready 中按类型一次性构建，
## 故复用时类型必须一致。做成实例（而非静态池）随场景一起销毁，
## 规避 reload_current_scene() 后静态结构持有失效引用。
class_name EnemyPool
extends Node2D

var _scene: PackedScene = preload("res://scenes/enemy.tscn")

## enemy_type -> Array[Enemy]（已回收、待复用）
var _free: Dictionary = {}

## 取出一只指定类型的敌人（复用空闲实例或新建）；调用方随后调用 enemy.spawn(data)
func acquire(enemy_type: String) -> Enemy:
	var bucket: Array = _free.get(enemy_type, [])
	if not bucket.is_empty():
		return bucket.pop_back()
	# 新建实例：类型须在 add_child(_ready) 前设好，供按类型一次性构建精灵/阴影/碰撞盒
	var enemy := _scene.instantiate() as Enemy
	enemy.enemy_type = enemy_type
	enemy.set_pool(self)
	add_child(enemy)
	return enemy

## 回收一只敌人（死亡/到达终点后由敌人自身调用），按类型放回空闲桶
func release(enemy: Enemy) -> void:
	var bucket: Array = _free.get(enemy.enemy_type, [])
	bucket.append(enemy)
	_free[enemy.enemy_type] = bucket
