clc; clear;

imagePath = input('Enter the image path: ', 's');
imagePath = strrep(imagePath, '"', '');

image = imread(imagePath);
grayImage = rgb2gray(image);
grayImage = imgaussfilt(grayImage, 1);

thresholdUpper = 80;
cracks = grayImage < thresholdUpper;

edges = edge(grayImage, 'Canny', [0.1, 0.3]);
edges = imdilate(edges, strel('line', 5, 0));
cracks = cracks | edges;

cracks = imdilate(cracks, strel('line', 5, 0));
cracks = bwareaopen(cracks, 100);

connectedComponents = bwconncomp(cracks);
stats = regionprops(connectedComponents, 'BoundingBox', 'Area', 'MajorAxisLength', 'MinorAxisLength', 'Orientation');

minCrackArea = 500;
scalingFactor = 0.5;
scalingFactorArea = scalingFactor^2;

crackCategories = {'Very Low Risk', 'Low Risk', 'Moderate Risk', 'Dangerous', 'Very Dangerous'};
orientationCategories = {'Horizontal', 'Vertical', 'Diagonal'};

crackClassifications = [];
largeCracks = false(size(cracks));

disp('--- Detected Crack Information ---');
crackID = 0;
for i = 1:length(stats)
    if stats(i).Area >= minCrackArea
        crackID = crackID + 1;
        largeCracks(connectedComponents.PixelIdxList{i}) = true;

        boundingBox = stats(i).BoundingBox;
        widthMM = boundingBox(3) * scalingFactor;
        heightMM = boundingBox(4) * scalingFactor;
        majorAxisMM = stats(i).MajorAxisLength * scalingFactor;
        minorAxisMM = stats(i).MinorAxisLength * scalingFactor;
        areaMM2 = stats(i).Area * scalingFactorArea;
        areaCM2 = areaMM2 / 100;

        if areaCM2 < 10
            riskCategory = crackCategories{1};
        elseif areaCM2 >= 10 && areaCM2 < 30
            riskCategory = crackCategories{2};
        elseif areaCM2 >= 30 && areaCM2 < 50
            riskCategory = crackCategories{3};
        elseif areaCM2 >= 50 && areaCM2 < 80
            riskCategory = crackCategories{4};
        else
            riskCategory = crackCategories{5};
        end

        orientationAngle = stats(i).Orientation;
        if (orientationAngle >= -45 && orientationAngle <= 45)
            orientationCategory = orientationCategories{1};
        elseif (orientationAngle > 45 && orientationAngle < 135)
            orientationCategory = orientationCategories{2};
        else
            orientationCategory = orientationCategories{3};
        end

        crackClassifications = [crackClassifications; struct('CrackID', crackID, 'AreaCM2', areaCM2, ...
            'Category', riskCategory, 'WidthMM', widthMM, 'HeightMM', heightMM, ...
            'MajorAxisMM', majorAxisMM, 'MinorAxisMM', minorAxisMM, ...
            'Orientation', orientationCategory)];

        fprintf('Crack ID: %d\n', crackID);
        fprintf(' - Area: %.2f cm²\n', areaCM2);
        fprintf(' - Risk Category: %s\n', riskCategory);
        fprintf(' - Width: %.2f mm, Height: %.2f mm\n', widthMM, heightMM);
        fprintf(' - Major Axis Length: %.2f mm\n', majorAxisMM);
        fprintf(' - Minor Axis Length: %.2f mm\n', minorAxisMM);
        fprintf(' - Orientation: %s\n', orientationCategory);
        fprintf('---------------------------\n');
    end
end

maskedImage = image;
maskedImage(repmat(largeCracks, [1, 1, 3])) = 0;
maskedImage(:,:,1) = maskedImage(:,:,1) + uint8(largeCracks) * 255;

figure; imshow(maskedImage); title('Detected Cracks Labeled');
hold on;
for i = 1:length(crackClassifications)
    boundingBox = stats(i).BoundingBox;
    classification = crackClassifications(i);
    text(boundingBox(1), boundingBox(2) - 10, sprintf('Crack %d', classification.CrackID), ...
        'Color', 'yellow', 'FontSize', 12, 'FontWeight', 'bold');
end
hold off;
