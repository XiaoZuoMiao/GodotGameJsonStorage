extends Object
class_name JsonSerializer
## 自定义类管理器，为静态工厂类。绝对不允许实例化，除非你知道你自己在做什么

## 将Json实例化，必须是元数据metadata/_custom_type_script有效的Json/Dictionary数据，适用全自定义class_name类
static func CreateObject(Dict: Dictionary) -> Object:
	var UR: Object = null
	if !Dict.keys().has("metadata/_custom_type_script"):
		return UR
	var ScriptRes: Variant = load(Dict["metadata/_custom_type_script"])
	if !(ScriptRes is GDScript):
		return UR
	var IScript: Variant = ScriptRes.new()
	UR = IScript
	for i in Dict:
		if Dict[i] is Dictionary:
			if Dict[i].keys().has("metadata/_custom_type_script"):
				UR.set(i, CreateObject(Dict[i]))
			else:
				UR.set(i, Dict[i])
		elif Dict[i] is Array:  # 添加：处理数组嵌套对象
			var new_array: Array = []
			for item in Dict[i]:
				if item is Dictionary and item.keys().has("metadata/_custom_type_script"):
					new_array.append(CreateObject(item))
				else:
					new_array.append(item)
			UR.set(i, new_array)
		else:
			UR.set(i, Dict[i])
	return UR

##将IObject返回于Dictionary（Json）格式，ABObject必须为IObject的基类，如果FreeAB为true，将强行释放ABObject
static func ObjectGetDictionory(IObject: Object, ABObject: Object = null, FreeAB:bool = false) -> Dictionary:
	var BaseRes: Object = ABObject
	var BaseKeys: Array[String] = []
	UpdateMataDeta(IObject)
	if IObject == ABObject or ( !IObject or !ABObject ):
		return {}
	for i in BaseRes.get_property_list():
		BaseKeys.push_back(i["name"])
	var Tamp: Dictionary = {}
	for i in IObject.get_property_list():
		var IKey: String = i["name"]
		var Getr: Variant = IObject.get(IKey)
		if Getr != null and !BaseKeys.has(IKey):
			if Getr is Object:
				if Getr.has_method(&"GetDictory"):
					if UpdateMataDeta(Getr): 
						Tamp[IKey] = Getr.GetDictory()
					else: 
						Tamp[IKey] = Getr
				elif Getr is Resource:
					# 修复：检查资源路径是否有效
					if Getr.resource_path != "":
						Tamp[IKey] = ResourceUID.path_to_uid(Getr.resource_path)
					else:
						Tamp[IKey] = null
			else:
				#非继承自GodotObject的容器类或基础数据处理区
				if Getr is Array:
					Tamp[IKey] = VarGetDictionory(Getr)
				if Getr is Dictionary:
					Tamp[IKey] = VarGetDictionory(Getr)
				else:
					Tamp[IKey] = IObject.get(IKey)
	if FreeAB: ABObject.free()
	return Tamp

##ObjectGetDictionory的简化版本，
static func EasyObjectGetDictionary(IObject: Object) -> Dictionary:
	return ObjectGetDictionory(IObject,GetParentInstance(IObject),true)

static func VarGetDictionory(IVariant: Variant) -> Variant:
	var Relest: = {}
	var SetTag: Callable = func(Stri: String): Relest["tag"] = Stri
	if IVariant is Object:
		return ObjectGetDictionory(IVariant,GetParentInstance(IVariant),true)
	elif IVariant is Vector2:
		SetTag.call("Vector2")
		Relest["x"] = IVariant.x
		Relest["y"] = IVariant.y
	elif IVariant is Vector3:
		SetTag.call("Vector3")
		Relest["x"] = IVariant.x
		Relest["y"] = IVariant.y
		Relest["z"] = IVariant.z
	elif IVariant is Vector4:
		SetTag.call("Vector3")
		Relest["x"] = IVariant.x
		Relest["y"] = IVariant.y
		Relest["z"] = IVariant.z
		Relest["w"] = IVariant.w
	elif IVariant is Vector2i:
		SetTag.call("Vector2i")
		Relest["x"] = IVariant.x
		Relest["y"] = IVariant.y
	elif IVariant is Vector3i:
		SetTag.call("Vector3i")
		Relest["x"] = IVariant.x
		Relest["y"] = IVariant.y
		Relest["z"] = IVariant.z
	elif IVariant is Vector4i:
		SetTag.call("Vector3i")
		Relest["x"] = IVariant.x
		Relest["y"] = IVariant.y
		Relest["z"] = IVariant.z
		Relest["w"] = IVariant.w
	elif IVariant is Array:
		var RelArray: Array = []
		for i in IVariant:
			RelArray.push_back(VarGetDictionory(i))
		return RelArray
	elif IVariant is Dictionary:
		var RelArray: Dictionary = {}
		for i in IVariant:
			RelArray[VarGetDictionory(i)] = VarGetDictionory(IVariant[i])
		return RelArray
	if Relest != {}:
		return Relest
	return IVariant

## 获取任意对象的父类实例
static func GetParentInstance(obj: Object) -> Object:
	if obj == null: return null
	var script: GDScript = obj.get_script()
	if script:
		var base_script: GDScript = script.get_base_script()
		if base_script: return base_script.new()
		# 拿内置类名
		var builtin_parent: String = script.get_instance_base_type()
		if ClassDB.class_exists(builtin_parent):
			return ClassDB.instantiate(builtin_parent)
		return null
	#ClassDB
	var class_namea: String = obj.get_class()
	var parent_class: String = ClassDB.get_parent_class(class_namea)
	if parent_class != "" and ClassDB.class_exists(parent_class):
		var relest = ClassDB.instantiate(parent_class)
		if !relest: return ClassDB.instantiate(ClassDB.get_parent_class(parent_class))
		return relest
	return null

func _ready() -> void:
	print(GetParentInstance(Node2D.new()))

## 更新Getr元数据脚本路径，基础脚本必须在res://路径中存在
static func UpdateMataDeta(Getr: Object) -> bool:
	var IsHasMeta: bool = true
	if Getr.get_meta("_custom_type_script", "null") == "null":
		IsHasMeta = false
	var Gds: Variant = Getr.get_script()
	if Gds is GDScript:
		if ResourceLoader.exists(Gds.resource_path):
			Getr.set_meta("_custom_type_script", ResourceUID.path_to_uid(Gds.resource_path))
			IsHasMeta = true
		else:
			var BGds: Variant = Gds.get_base_script()
			if BGds is GDScript:  # 修复：类型检查
				if ResourceLoader.exists(BGds.resource_path):
					Getr.set_meta("_custom_type_script", ResourceUID.path_to_uid(BGds.resource_path))
					IsHasMeta = true
	return IsHasMeta
