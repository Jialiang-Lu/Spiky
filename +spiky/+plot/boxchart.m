function h = boxchart(dataCell, columnNames, rowNames)
    %BOXCHART Plots grouped box plots using a 2D cell array as input.
    %
    %   boxchart(dataCell, columnNames, rowNames)
    %
    %   dataCell: 2D cell array, each column is a group, each row is a color group
    %   columnNames: string array for x-axis labels
    %   rowNames: string array for legend labels
    
    
    arguments
        dataCell cell
        columnNames string
        rowNames string = ""
    end
    
    numGroups = size(dataCell, 2); % Number of x-axis groups
    numColors = size(dataCell, 1); % Number of color-coded groups
    
    hold on;
    xPositions = [];
    colorGroup = [];
    allData = [];
    
    % Prepare x positions, color groups, and flatten data for boxchart input
    for col = 1:numGroups
        for row = 1:numColors
            dataVector = dataCell{row, col}(:);
            numEntries = numel(dataVector);
            
            xPositions = [xPositions; repmat(col, numEntries, 1)];
            colorGroup = [colorGroup; repmat(row, numEntries, 1)];
            allData = [allData; dataVector];
        end
    end
    
    % Create box chart with grouping by x position and color
    h1 = boxchart(xPositions, allData, "GroupByColor", colorGroup);
    
    xticks(1:numGroups);
    xticklabels(columnNames);
    if numColors>1
        legend(rowNames, "Location", "best");
    end
    if nargout>0
        h = h1;
    end
end
