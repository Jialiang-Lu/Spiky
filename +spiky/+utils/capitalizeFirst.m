function str = capitalizeFirst(str)

str = upper(extractBefore(str, 2)) + extractAfter(str, 1);

end