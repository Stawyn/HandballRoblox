return function (Stands: {[number]: BasePart}, FieldPosition: number): {[number]: BasePart}
	table.sort(Stands, function(a, b)
		local firstMagnitude = (a.Position - FieldPosition).Magnitude
		local secondMagnitude = (b.Position - FieldPosition).Magnitude
		
		return firstMagnitude < secondMagnitude
	end)
	
	return Stands
end
