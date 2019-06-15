function maskRefined= maskRefine( maskImageVolume )
% This function is used to refine the left and right lung lobe mask
% seperatedly. Left and right lung lobe are detected in 3D first and then
% left and right lobe masks on each slice are processed seperately.
%
% new modification: add erosion in the end to shrink the lung lobe boundary
%
% Copyright (C) by Shiwen Shen

[x,y,z]=size(maskImageVolume);
% viewBinaryMask(maskImageVolume);

%image open 
se = strel('disk',2);
for i=1:z
    maskImageVolume(:,:,i)=imopen(maskImageVolume(:,:,i),se);
end
% viewBinaryMask(maskImageVolume);


CC = bwconncomp(maskImageVolume);
numPixels = cellfun(@numel,CC.PixelIdxList);
[largest1,idx1] = max(numPixels);
numPixels(idx1)=0;
[largest2,idx2] = max(numPixels);
largeLobe= maskImageVolume&0;
largeLobe(CC.PixelIdxList{idx1}) = 1;
se = strel('disk',8);
for i=1:z
    largeLobe(:,:,i)=imclose(largeLobe(:,:,i),se);
end
% viewBinaryMask(largeLobe);



smallLobe= maskImageVolume&0;

if largest2~=0
    if (largest1/largest2)<3
        smallLobe(CC.PixelIdxList{idx2}) = 1;
        for i=1:z
            smallLobe(:,:,i)=imclose(smallLobe(:,:,i),se);
        end
    end
end
% viewBinaryMask(largeLobe);

maskRefined=(largeLobe|smallLobe);
for i=1:z
    maskRefined(:,:,i)=imfill(maskRefined(:,:,i),'holes');
end


