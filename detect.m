% crop images first to reduce processing time (or later to increase presision)
% imin to detect minimum intensity
% save Imin and zmap
% crop now if cropping wasn't performed earlier
% threshhold and morphological operators
% remove problematic regions (like vorticella)
% detect particle centers
% save

%% Method attempting to show dragable cropbox of 1024 or 2048

% I = imread('DH_0001.tif');
% figure
% imshow(I);
% waitforbuttonpress
% point1 = get(gca,'CurrentPoint') % button down detected
% rect = [point1(1,1) point1(1,2) 50 100];
% [r2] = dragrect(rect);
% J = imcrop(I, rect);
% figure,imshow(J),title('Cropped Image');
% 
% figure, imshow('pout.tif');
% h = imrect;
% position = wait(h);


%% PD_IMINSAVE_GPU - Find the minimum intensity of all images in folder and saves them
% 
% Version 1.0


clear all
tic

dirname = '';
filename    = 'Basler_acA2040-25gm__21407047__20141125_173751726_';
ext = 'tiff';
backgroundfile = 'background.mat';
mag = 4; %Magnification
ps = 5.5E-6; % Pixel Size in meters
refractindex = 1.33;
lambda = 632.8E-9; % Laser wavelength in meters
% z1=0E-3;
% z2=7.9E-3;
steps=2201;
% vortloc=[1180, 2110, 2.7E-3]; %location of vorticella in "cuvette in focus"
% vortloc=[1535, 2105, 0]; %location of vorticella in "vort in focus"
% thlevel = 0.0005;
dilaterode = 35;
derstr = 'D1E0R8D1D1';
zpad=2048;
radix2=2048;
firstframe = 1;
lastframe = 'numfiles';
%lastframe = '10';
skipframes = 1; % skipframes = 1 is default
IminPathStr = 'matfiles-5imgBG';
IminPathStr = 'matfiles';
OutputPathStr = 'analysis-20141128';
% maxint=2; %overide default max intensity: 2*mean(Imin(:))
% test=1;


load('constants.mat')
thlevel = 0.03;

Zin=linspace(z1,z2,steps);
Zout=Zin;
% rect = [vortloc(1)-512,vortloc(2)-1024,1023,1023]; %for "cuvette in focus" data
% rect = [1550-512,2070-1024,1023,1023]; %for "vort in focus" data
% rect = [2560-radix2,2160-radix2,radix2-1,radix2-1]; %bottom right
rect = [vortloc(1)-radix2/2,vortloc(2)-radix2,radix2-1,radix2-1]; %Cropping
rect = [0,0,2048,2048]; %temp Cropping

ps = ps / mag; % Effective Pixel Size in meters
lambda = lambda / refractindex; % Effective laser wavelength in meters


warning('off','images:imfindcircles:warnForLargeRadiusRange');
warning('off','images:imfindcircles:warnForSmallRadius');



filename = strcat(dirname,filename);
filesort = dir([filename,'*.',ext]);
numfiles = numel(filesort);
numframes = floor((eval(lastframe) - firstframe + 1)/skipframes);
LocCentroid(numframes).time=[];
Eout(numfiles).time=[];
for L = 1:numfiles
    [filesort(L).pathstr, filesort(L).firstname, filesort(L).ext] = ...
        fileparts([filesort(L).name]);
    %filesort(i).matname=strcat(filesort(i).matname,'.mat');
end


%
varnam=who('-file',backgroundfile);
background=load(backgroundfile,varnam{1});
background=gpuArray(background.(varnam{1}));

if ~exist(OutputPathStr, 'dir')
  mkdir(OutputPathStr);
end

if ~exist(IminPathStr, 'dir')
  mkdir(IminPathStr);
end

% for L=1:1:numfiles
% %     Holo = imread([filesort(L).name]);
%     Holo = double(gpuArray(imread([filesort(L).name])))./background;
%     Ein = imcrop(Holo,rect);
%     maxint = 2*mean(Ein(:));
%     Ein(Ein>maxint) = maxint;
%     Ein = Ein./maxint;
%     Ein = gather(Ein);
%     imwrite(Ein,['1024\',filesort(L).name]);
% end

%

% Ein = gather((double(imread([filesort(1).name]))./background));
% Ein = gather((double(imread([filesort(1).name]))));
% Ein = gather(double(background));
Ein = gather((double(imread([filesort(1).name]))./double(imread([filesort(skipframes+1).name]))));
if ~exist('maxint')
    maxint=2*mean(Ein(:));
end

if exist('test')
    numfiles=test;
end


%% Create Dilate and Erode Parameters
if dilaterode <= 3
    disk0 = logical(ones(dilaterode-1));
    disk1 = logical(ones(dilaterode));
elseif dilaterode == 4
    dilaterode = 3;
    disk0 = logical(ones(dilaterode));
    dilaterode = 4;
    disk1 = getnhood(strel('diamond', round((dilaterode+1)/2)));
    disk1 = disk1(2:end-1,2:end-1);
    disk1(:,dilaterode/2) = [];
    disk1(dilaterode/2,:) = [];
elseif dilaterode == 5
    dilaterode = 4;
    disk0 = getnhood(strel('diamond', round((dilaterode+1)/2)));
    disk0 = disk0(2:end-1,2:end-1);
    disk0(:,dilaterode/2) = [];
    disk0(dilaterode/2,:) = [];
    dilaterode = 5;
    disk1 = getnhood(strel('diamond', round((dilaterode)/2)));
    disk1 = disk1(2:end-1,2:end-1);
elseif dilaterode == 6
    dilaterode = 5;
    disk0 = getnhood(strel('diamond', round((dilaterode)/2)));
    disk0 = disk0(2:end-1,2:end-1);
    dilaterode = 6;
    disk1 = getnhood(strel('diamond', round((dilaterode+1)/2)));
    disk1 = disk1(2:end-1,2:end-1);
    disk1(:,dilaterode/2) = [];
    disk1(dilaterode/2,:) = [];
elseif dilaterode == 7
    dilaterode = 6;
    disk0 = getnhood(strel('diamond', round((dilaterode+1)/2)));
    disk0 = disk0(2:end-1,2:end-1);
    disk0(:,dilaterode/2) = [];
    disk0(dilaterode/2,:) = [];
    dilaterode = 7;
    disk1 = getnhood(strel('diamond', round((dilaterode)/2)));
    disk1 = disk1(2:end-1,2:end-1);
elseif dilaterode == 8
    dilaterode = 7;
    disk0 = getnhood(strel('diamond', round((dilaterode)/2)));
    disk0 = disk0(2:end-1,2:end-1);
    dilaterode = 8;
    disk1 = getnhood(strel('disk', 5));
    disk1(:,dilaterode/2) = [];
    disk1(dilaterode/2,:) = [];
elseif dilaterode == 9
    dilaterode = 8;
    disk0 = getnhood(strel('disk', 5));
    disk0(:,dilaterode/2) = [];
    disk0(dilaterode/2,:) = [];
    dilaterode = 9;
    [xx,yy] = ndgrid((1:dilaterode)-((dilaterode+1)/2),(1:dilaterode)-((dilaterode+1)/2));
    disk1 = (xx.^2 + yy.^2)<((dilaterode+1)/2)^2;
elseif dilaterode == 35
    dilaterode = 3;
    disk0 = logical(ones(dilaterode));
    dilaterode = 5;
    disk1 = getnhood(strel('diamond', round((dilaterode)/2)));
    disk1 = disk1(2:end-1,2:end-1);
else
    [xx,yy] = ndgrid((1:dilaterode)-((dilaterode+1)/2),(1:dilaterode)-((dilaterode+1)/2));
    disk1 = (xx.^2 + yy.^2)<((dilaterode+1)/2)^2;
    dilaterode=dilaterode-1;
    [xx,yy] = ndgrid((1:dilaterode)-((dilaterode+1)/2),(1:dilaterode)-((dilaterode+1)/2));
    disk0 = (xx.^2 + yy.^2)<((dilaterode+1)/2)^2;
    % disk = 1 - disk;
end


%% Create Imin MAT files and run Particle Detection together
%{
loop = 0;
wb = waitbar(0/numframes,'Analysing Data for Imin and Detecting Particles');
for L=firstframe:skipframes:eval(lastframe)
    loop = loop + 1;
    % import data from tif files.
    % Ein = (double(imread([filesort(L).name])));o
%     Holo = background;
%     background = double(imread([filesort(L+skipframes).name]));
%     Ein = Holo./background;
    Ein = (double(imread([filesort(L).name]))./background);
    Ein = imcrop(Ein,rect);
    % Ein=Ein(vortloc(2)-radix2+1:vortloc(2),vortloc(1)-radix2/2:vortloc(1)-1+radix2/2);
    %Ein=Ein(1882-768:1882+255,1353-511:1353+512);
    %Ein = (double(background));
    %Ein(isnan(Ein)) = mean(background(:));
    Ein(Ein>maxint)=maxint;

    
    [Imin, zmap] = imin(Ein,lambda,Zout,ps,zpad);
    save([IminPathStr,'\',filesort(L).firstname,'.mat'],'Imin','zmap','-v7.3');
    
    
    % The following 3 lines saves cropped and scaled region of Ein
%     Ein = Ein./maxint;
%     Ein = gather(Ein);
%     imwrite(Ein,[OutputPathStr,'\',filesort(L).name]);



    %% Detect Particles and Save
    [Xauto_min,Yauto_min,Zauto_min,Xauto_centroid,Yauto_centroid,Zauto_centroid] = detection(Imin, zmap, thlevel, disk0, disk1, derstr);
    LocCentroid(loop).time=[Xauto_min;Yauto_min;Zauto_min;Xauto_centroid;Yauto_centroid;Zauto_centroid]';

    
    waitbar(loop/numframes,wb);
end

Ein=gather(Ein);
background=gather(background);
maxint=gather(maxint);
close(wb);
save([OutputPathStr,'\',filename(1:end-1),'-th',num2str(thlevel,'%10.0E'),'_dernum',num2str(dilaterode,2),'_day',num2str(round(now*1E5)),'.mat'], 'LocCentroid')
toc
%}


%% Create Imin MAT files only
%{
loop = 0;
wb = waitbar(0/numframes,'Analysing Data for Imin');
for L=firstframe:skipframes:eval(lastframe)
    loop = loop + 1;
    % import data from tif files.
    % Ein = (double(imread([filesort(L).name])));
    Ein = (double(imread([filesort(L).name]))./background);
    Ein = imcrop(Ein,rect);
    %Ein = (double(background));
    %Ein(isnan(Ein)) = mean(background(:));
    Ein(Ein>maxint)=maxint;

    
    [Imin, zmap] = imin(Ein,lambda,Zout,ps,zpad);
    save([IminPathStr,'\',filesort(L).firstname,'.mat'],'Imin','zmap','-v7.3');
    
    
    % The following 3 lines saves cropped and scaled region of Ein
%     Ein = Ein./maxint;
%     Ein = gather(Ein);
%     imwrite(Ein,[OutputPathStr,'\',filesort(L).name]);


    waitbar(loop/numframes,wb);
end

Ein=gather(Ein);
background=gather(background);
maxint=gather(maxint);
close(wb);
toc
%}

% %% Thresholding and Morphological Operators
% %
% function [Xauto,Yauto,Zauto_centroid,Zauto_mean,Zauto_min] = detection(Imin, zmap, thlevel, dilaterode);
% th = Imin<thlevel;
% disk1 = strel('disk', dilatenum, 0);
% th = imdilate(th,strel('disk', dilaterode, 0));
% th = imerode(th,strel('disk', dilaterode, 0));
% th = imdilate(th,strel('disk', dilaterode, 0));
% th = imdilate(th,strel('disk', dilaterode, 0));
% th = imerode(th,strel('disk', dilaterode, 0));
% th = imerode(th,strel('disk', dilaterode, 0));
% th = imerode(th,strel('disk', dilaterode, 0));
% th = bwlabel(th,4);
% autodetstruct = regionprops(th,'Centroid','PixelIdxList');
% xy = [autodetstruct.Centroid];
% Xauto = xy(1:2:end);
% Yauto = xy(2:2:end);
% 
% %Linear Interpolation Method, using 4 pixels nearest centroid(X-Y) to
% %determine z-depth. more acurate centroid method
% Zauto_centroid = interp2(1:size(zmap,2),1:size(zmap,1),zmap,Xauto,Yauto);
% 
% %Determine mean Z-value from all pixels in region (biasing errors)
% Zauto_mean=zeros(size(Xauto));
% 
% %Depth of Minimum intensity pixel
% Zauto_min=zeros(size(Xauto));
% for i = 1:numel(autodetstruct)
%     idx = autodetstruct(i).PixelIdxList;
%     Zauto_mean(i) = mean(zmap(idx));
%     
%     particlepixels = Imin(idx);
%     [~,minidx] = min(particlepixels);
%     Zauto_min(i) = zmap(idx(minidx));
% end




%% Detect Particles and Save
%
loop = 0;
wb = waitbar(0/numframes,'Locating Particle Locations from Data');
%for L=1:numframes
for L=firstframe:skipframes:eval(lastframe)
    loop = loop + 1;


    % load data from mat files.
    load([IminPathStr,'/',filesort(L).firstname,'.mat']);
    % 
    %% Detect Particles and Save
    [Xauto_min,Yauto_min,Zauto_min,Xauto_centroid,Yauto_centroid,Zauto_centroid] = detection(Imin, zmap, thlevel, disk0, disk1, derstr);
    LocCentroid(loop).time=[Xauto_min;Yauto_min;Zauto_min;Xauto_centroid;Yauto_centroid;Zauto_centroid]';
    %
    %
    waitbar(loop/numframes,wb);
end

close(wb);
save([OutputPathStr,'/',filename(1:end-1),'-th',num2str(thlevel,'%10.0E'),'_dernum',num2str(dilaterode,2),'_day',num2str(round(now*1E5)),'.mat'], 'LocCentroid')
%}
toc
