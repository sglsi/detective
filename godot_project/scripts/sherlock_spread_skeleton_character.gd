extends Node2D
const SkeletonCharacter2D = preload("res://scripts/characters/skeleton_character.gd")
const SherlockSpreadRig = preload("res://scripts/rig/sherlock_spread_rig.gd")

@onready var _view: SubViewport = $View
@onready var _hero: SkeletonCharacter2D = $View/Hero

func _ready() -> void:
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_hero.build_from_def(SherlockSpreadRig.rig_def())
	_hero.play("idle")
