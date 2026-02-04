local Vector = {}

function Vector:Vector3ToVectorLib(v: Vector3)
	return vector.create(v.X, v.Y, v.Z)
end

function Vector:VectorLibToVector3(v: vector)
	return Vector3.new(v.x, v.y, v.z)
end

return Vector