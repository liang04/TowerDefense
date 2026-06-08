## 子弹对象池（挂在主场景的 Projectiles 容器节点上）
## 高火力时子弹频繁生成/销毁，逐个 instantiate/queue_free 会带来反复的
## 内存分配与 GC 停顿。池化后复用实例：命中的子弹回收进空闲链表，
## 下次发射直接取出重置，避免节点的反复创建与释放。
##
## 故意做成实例（而非静态池）：随场景一起销毁重建，规避 reload_current_scene()
## 后静态链表持有失效引用的问题。
class_name ProjectilePool
extends Node2D

var _scene: PackedScene = preload("res://scenes/projectile.tscn")

## 空闲（已回收、待复用）的子弹
var _free: Array[Projectile] = []

## 取出一颗已激活的子弹（复用空闲实例或新建），调用方负责随后调用 setup()
func acquire() -> Projectile:
	var projectile: Projectile
	if _free.is_empty():
		projectile = _scene.instantiate() as Projectile
		projectile.set_pool(self)
		add_child(projectile)
	else:
		projectile = _free.pop_back()
	projectile.activate()
	return projectile

## 回收一颗子弹（命中/失效后由子弹自身调用），停用并放回空闲链表
func release(projectile: Projectile) -> void:
	projectile.deactivate()
	_free.append(projectile)
