local Math = {}

function Math:CheckApproxEqual(approx: number, target: number)
	return math.abs(approx - target) < 1e-6
end

function Math:TernarySearch(f: (number) -> number, left: number, right: number)
	local iterations = 20
	
	for i = 1, iterations do
		local leftThird = left + (right - left) / 3
		local rightThird = right - (right - left) / 3
		
		if f(leftThird) < f(rightThird) then
			right = rightThird
		else
			left = leftThird
		end
	end
	
	return (left + right) / 2
end

return Math