extends Node2D
const SkeletonCharacter2D = preload("res://scripts/characters/skeleton_character.gd")
const SherlockRig = preload("res://scripts/rig/sherlock_rig.gd")

@onready var _view: SubViewport = $View
@onready var _hero: SkeletonCharacter2D = $View/Hero

func _ready() -> void:
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_hero.build_from_def(SherlockRig.rig_def())
	_hero.play("idle")
