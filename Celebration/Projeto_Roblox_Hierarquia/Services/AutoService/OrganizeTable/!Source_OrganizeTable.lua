return function(tableToOrganize)
	local organizedTable = {}

	for _, value in ipairs(tableToOrganize) do
		if value ~= nil and value ~= "" then
			table.insert(organizedTable, value)
		end
	end

	return organizedTable
end
