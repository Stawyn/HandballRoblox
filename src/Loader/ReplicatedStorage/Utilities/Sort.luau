local Sort = {}

function Sort:InsertionSort(t: {number}): {number}
	local n = #t

	if n <= 1 then
		return t
	end

	for i = 2, n do
		local key = t[i]
		local j = i - 1

		while j >= 1 and t[j] > key do
			t[j+1] = t[j]
			j -= 1
		end

		t[j+1] = key
	end

	return t
end

return Sort
