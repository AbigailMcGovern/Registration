function apply_deformation_v_0_12_nissl(template_names,target_dir,detailed_output_dir,outdir)
% keyboard

% clear all;
% close all;
% fclose all;

% these files should be distributed along
% addpath /cis/home/dtward/Functions/plotting
% addpath /cis/home/dtward/Functions/vtk
addpath Functions/plotting
addpath Functions/vtk



rng(1);
colors = rand(256,3);

%%
% input files
% name = 'v20_711';
% target_dir = '/cis/home/dtward/Documents/intensity_transform_and_missing_data/csh_slices/toDaniel/MD711/';
% outdir = 'registered_v02_711/';
% the full res template
% this is just for making pictures
% res = 50;
% template_name = ['/cis/home/dtward/Documents/ARA/Mouse_CCF/vtk/annotation_' num2str(res) '.vtk'];
if isempty(template_names)
    save_qc = 0;
else
    save_qc = 1;
end

%%
% load template
if save_qc
    for c = 1 : length(template_names)
        [xI{c},yI{c},zI{c},I{c},title_,names] = read_vtk_image(template_names{c});
        I{c} = double(I{c});
    end
end

%%
% make output directory
if ~exist(outdir,'dir')
    mkdir(outdir)
end


%%
% first thing is now to get slice thicknesses and location
geometry_file = dir([target_dir '*.csv']);
fid = fopen([target_dir geometry_file(1).name],'rt');
line = fgetl(fid); % ignore the first line
% it should say
% filename, nx, ny, nz, dx, dy, dz, x0, y0, z0

csv_data = {};
count = 0;
while 1
    line = fgetl(fid);
    if line == -1
        break
    end
    count = count + 1;
    % process this line, splitting at commas
    csv_data(count,:) = strsplit(line,',');
    %     
end
fclose(fid);
files = csv_data(:,1);
nxJ = cellfun(@(x)str2num(x), csv_data(:,2:3));
dxJ = cellfun(@(x)str2num(x), csv_data(:,5:6));

x0J = cellfun(@(x)str2num(x), csv_data(:,8:9));
z0J = cellfun(@(x)str2num(x), csv_data(:,10));

zJ = z0J;
dzJ = cellfun(@(x) str2num(x), csv_data(:,7));

for f = 1 : length(files)
    xJ{f} = x0J(f,1) + (0:nxJ(f,1)-1)*dxJ(f,1);
    yJ{f} = x0J(f,2) + (0:nxJ(f,2)-1)*dxJ(f,2);
end


%%
% get the transforms
Avars = load([detailed_output_dir 'down1_A.mat']);
A = Avars.A;
AJ = Avars.AJ;
vvars = load([detailed_output_dir 'down1_v.mat']);
dxVJ = zeros(length(files),2);
for f = 1 : length(files)
    dxVJ(f,:) = [vvars.xJ{f}(2)-vvars.xJ{f}(1),vvars.yJ{f}(2)-vvars.yJ{f}(1)];
end

vtx = vvars.vtx;
vty = vvars.vty;
vtz = vvars.vtz;

xV = vvars.xI;
yV = vvars.yI;
zV = vvars.zI;
[XV,YV,ZV] = meshgrid(xV,yV,zV);

nt = size(vtx,4);
dt = 1.0/nt;

vJtx = vvars.vJtx;
vJty = vvars.vJty;
ntJ = size(vJtx{1},3);
dtJ = 1/ntJ;


%%
% now I have to flow the 3D transform
%% first the deformation
phiinvx = XV;
phiinvy = YV;
phiinvz = ZV;
for t = 1 : nt
    % update phi
    Xs = XV - vtx(:,:,:,t)*dt;
    Ys = YV - vty(:,:,:,t)*dt;
    Zs = ZV - vtz(:,:,:,t)*dt;
    % subtract and add identity
    F = griddedInterpolant({yV,xV,zV},phiinvx-XV,'linear','nearest');
    phiinvx = F(Ys,Xs,Zs) + Xs;
    F = griddedInterpolant({yV,xV,zV},phiinvy-YV,'linear','nearest');
    phiinvy = F(Ys,Xs,Zs) + Ys;
    F = griddedInterpolant({yV,xV,zV},phiinvz-ZV,'linear','nearest');
    phiinvz = F(Ys,Xs,Zs) + Zs;
end

phix = XV;
phiy = YV;
phiz = ZV;
for t = nt : -1 : 1
    % update phi
    Xs = XV + vtx(:,:,:,t)*dt;
    Ys = YV + vty(:,:,:,t)*dt;
    Zs = ZV + vtz(:,:,:,t)*dt;
    % subtract and add identity
    F = griddedInterpolant({yV,xV,zV},phiinvx-XV,'linear','nearest');
    phix = F(Ys,Xs,Zs) + Xs;
    F = griddedInterpolant({yV,xV,zV},phiinvy-YV,'linear','nearest');
    phiy = F(Ys,Xs,Zs) + Ys;
    F = griddedInterpolant({yV,xV,zV},phiinvz-ZV,'linear','nearest');
    phiz = F(Ys,Xs,Zs) + Zs;
end
Aphix = A(1,1)*phix + A(1,2)*phiy + A(1,3)*phiz + A(1,4);
Aphiy = A(2,1)*phix + A(2,2)*phiy + A(2,3)*phiz + A(2,4);
Aphiz = A(3,1)*phix + A(3,2)*phiy + A(3,3)*phiz + A(3,4);
% get det jac
dxV = [xV(2)-xV(1), yV(2)-yV(1), zV(2)-zV(1)];
[phix_x,phix_y,phix_z] = gradient(phix,dxV(1),dxV(2),dxV(3));
[phiy_x,phiy_y,phiy_z] = gradient(phiy,dxV(1),dxV(2),dxV(3));
[phiz_x,phiz_y,phiz_z] = gradient(phiz,dxV(1),dxV(2),dxV(3));
detjac = (phix_x.*(phiy_y.*phiz_z - phiy_z.*phiz_y) ...
    - phix_y.*(phiy_x.*phiz_z - phiy_z.*phiz_x) ...
    + phix_z.*(phiy_x.*phiz_y - phiy_y.*phiz_x))*det(A);
% write these out
if ~exist(outdir,'dir');mkdir(outdir);end;
write_vtk_image(xV,yV,zV,single(cat(4,Aphix-XV,Aphiy-YV,Aphiz-ZV)),[outdir 'atlas_to_registered_displacement.vtk'],'atlas_to_registered')
write_vtk_image(xV,yV,zV,single(detjac),[outdir 'atlas_to_registered_detjac.vtk'],'atlas_to_registered_detjac')

% we also want the velocity field
write_vtk_image(xV,yV,zV,single(permute(cat(5,vtx,vty,vtz),[1,2,3,5,4])),[outdir 'atlas_to_registered_velocity.vtk'],'atlas_to_registered_velocity')



%%
% now I have to loop through slices
for f = 1 : length(files)
    [dir_,fname_,ext_] = fileparts(files{f});
    % when writing vtk, I'll calculate dx from the "z" variable
    % so we need 2 elements
    zJ_write = zJ(f) + [0,1]*dzJ(f);
    xVJ = vvars.xJ{f};
    yVJ = vvars.yJ{f};
    [XVJ,YVJ] = meshgrid(xVJ,yVJ);
    
    %%
    % now I have to flow the 2D transform
    phiJinvx = XVJ;
    phiJinvy = YVJ;
    for t = 1 : ntJ
        % update phi
        Xs = XVJ - vJtx{f}(:,:,t)*dtJ;
        Ys = YVJ - vJty{f}(:,:,t)*dtJ;
        % subtract and add identity
        F = griddedInterpolant({yVJ,xVJ},phiJinvx-XVJ,'linear','nearest');
        phiJinvx = F(Ys,Xs) + Xs;
        F = griddedInterpolant({yVJ,xVJ},phiJinvy-YVJ,'linear','nearest');
        phiJinvy = F(Ys,Xs) + Ys;
    end
    
    %%
    % now I have to get coordinates for this image
    % we will apply the transformations to these points
    J = imread([target_dir files{f}]);
    [XJ,YJ] = meshgrid(xJ{f},yJ{f});
%     danfigure(1);
%     imagesc(xJ{f},yJ{f},J)
%     axis image

    %%
    % first apply the 2D affine
    BJ = inv(AJ(:,:,f));
    AJiX = BJ(1,1)*XJ + BJ(1,2)*YJ + BJ(1,3);
    AJiY = BJ(2,1)*XJ + BJ(2,2)*YJ + BJ(2,3);
    AJiZ = zJ(f); % identity
    
    %%
    % now apply 2D diffeo
    F = griddedInterpolant({yVJ,xVJ}, phiJinvx-XVJ, 'linear','nearest');
    phiJiAJiX = F(AJiY,AJiX) + AJiX;
    F = griddedInterpolant({yVJ,xVJ}, phiJinvy-YVJ, 'linear','nearest');
    phiJiAJiY = F(AJiY,AJiX) + AJiY;
    phiJiAJiZ = AJiZ; % identity
    
    %%
    % now apply the affine
    B = inv(A);
    AiPhiJiAJiX = B(1,1)*phiJiAJiX + B(1,2)*phiJiAJiY + B(1,3)*phiJiAJiZ + B(1,4);
    AiPhiJiAJiY = B(2,1)*phiJiAJiX + B(2,2)*phiJiAJiY + B(2,3)*phiJiAJiZ + B(2,4);
    AiPhiJiAJiZ = B(3,1)*phiJiAJiX + B(3,2)*phiJiAJiY + B(3,3)*phiJiAJiZ + B(3,4);
    
    %%
    % now apply the diffeo
    F = griddedInterpolant({yV,xV,zV}, phiinvx-XV, 'linear','nearest');
    phiiAiPhiJiAJiX = F(AiPhiJiAJiY,AiPhiJiAJiX,AiPhiJiAJiZ) + AiPhiJiAJiX;
    F = griddedInterpolant({yV,xV,zV}, phiinvy-YV, 'linear','nearest');
    phiiAiPhiJiAJiY = F(AiPhiJiAJiY,AiPhiJiAJiX,AiPhiJiAJiZ) + AiPhiJiAJiY;
    F = griddedInterpolant({yV,xV,zV}, phiinvz-ZV, 'linear','nearest');
    phiiAiPhiJiAJiZ = F(AiPhiJiAJiY,AiPhiJiAJiX,AiPhiJiAJiZ) + AiPhiJiAJiZ;
    
    
    %%
    % now I have to apply the transform to my atlas
    % we don't need to make this figure, just the "straight" version
    
    
    %%
    % we also need the "reconstruction" coordinates (backwards for slices)
    % make it the same size as the full res image
    phi1tJinvx = XVJ;
    phi1tJinvy = YVJ;
    for t = ntJ : -1 : 1 % I think I had this order wrong last time!
        % update phi
        Xs = XVJ + vJtx{f}(:,:,t)*dtJ;
        Ys = YVJ + vJty{f}(:,:,t)*dtJ;
        % subtract and add identity
        F = griddedInterpolant({yVJ,xVJ},phi1tJinvx-XVJ,'linear','nearest');
        phi1tJinvx = F(Ys,Xs) + Xs;
        F = griddedInterpolant({yVJ,xVJ},phi1tJinvy-YVJ,'linear','nearest');
        phi1tJinvy = F(Ys,Xs) + Ys;
    end
    % the reconstruction is gonna be 
    % AphiJ
    AJphiJX = AJ(1,1)*phi1tJinvx + AJ(1,2)*phi1tJinvy + AJ(1,3);
    AJphiJY = AJ(2,1)*phi1tJinvx + AJ(2,2)*phi1tJinvy + AJ(2,3);
    % upsample onto size of full res image
    F = griddedInterpolant({yVJ,xVJ},AJphiJX-XVJ,'linear','nearest');
    AJphiJX = F(YJ,XJ) + XJ;
    F = griddedInterpolant({yVJ,xVJ},AJphiJY-YVJ,'linear','nearest');
    AJphiJY = F(YJ,XJ) + YJ;
    
    % I don't need to save these because I'm only saving the straightened
    % version

    
    %%
    % okay actually this is what I want to do
    % I have a matrix A
    % I want to factor it 
    % A = BC
    % such that B is a rigid transform in XY
    % AND
    % a at the center pointing up on this slice, is again a vector at the
    % center pointing up    
    % so all we have to do is find what happens to a vector pointin gup
    % where does 0,0 on this slice end up?
    u0 = [0;0;zJ(f);1];
    v0 = A\u0;
    zatlas = v0(3);
    tmp = A*[0;0;zatlas;1];
    xyoff = tmp(1:2);
    
    
    % unit vector up
    v = [1;0;0;0];
    % what happens to unit vector
    Av = A*v;
    
    % so we want B or Axy to do two things
    % correct this translation (in xy)
    % and create this rotation (y component)
    theta = atan2(-Av(1),Av(2));
    % what rotation corresponded to this?
    R = [cos(theta),-sin(theta),0,0;
        sin(theta),cos(theta),0,0;
        0,0,1,0;
        0,0,0,1];
    
%     inv(R)*A*v has x component 0
    
    % so what I want is to say
    % first apply A
    % then shift back to center
    % then rotate to verticle
    % then inverse rotate
    % then inverse shift
    Shift = [1,0,0,xyoff(1);
        0,1,0,xyoff(2);
        0,0,1,0;
        0,0,0,1];
    Axyz = inv(R)*inv(Shift)*A;
    Axy = Shift*R;
    

    
    
    
    % get a 2D version    
    Axy_ = Axy([1,2,4],[1,2,4]);
    
    
    
    
    % so the better reconstruction
    % x \to Axy x \to phiJ(Axy(x)) \to AJ(phiJ(Axy(x)));
    % we need this forward transform to pull the image J backwards
    AxyX = Axy_(1,1)*XJ + Axy_(1,2)*YJ + Axy_(1,3);
    AxyY = Axy_(2,1)*XJ + Axy_(2,2)*YJ + Axy_(2,3);
    % now evaluate phiJ here
    F = griddedInterpolant({yVJ,xVJ},phi1tJinvx-XVJ,'linear','nearest');
    phiJAxyX = F(AxyY,AxyX) + AxyX;
    F = griddedInterpolant({yVJ,xVJ},phi1tJinvy-YVJ,'linear','nearest');
    phiJAxyY = F(AxyY,AxyX) + AxyY;
    % now apply AJ
    AJphiJAxyX = AJ(1,1,f)*phiJAxyX + AJ(1,2,f)*phiJAxyY + AJ(1,3,f);
    AJphiJAxyY = AJ(2,1,f)*phiJAxyX + AJ(2,2,f)*phiJAxyY + AJ(2,3,f);
    % let's deform J with this as a test
    Jrecon = zeros(size(J));
    for c = 1 : size(J,3)
        F = griddedInterpolant({yJ{f},xJ{f}},double(J(:,:,c))/255.0,'linear','nearest');
        Jrecon(:,:,c) = F(AJphiJAxyY,AJphiJAxyX);
    end


    % the transform to calculate Jrecon is a map from registered to input
    out = single(cat(4,AJphiJAxyX-XJ,AJphiJAxyY-YJ, zeros(size(AJphiJAxyX))));
    write_vtk_image(xJ{f},yJ{f},zJ_write,out,[outdir 'registered_to_input_displacement_' fname_ '.vtk'],'registered_to_input_displacement');

    
%     %%
    % now we need a transform from input to registered, its the inverse of
    % the above
    % y = AJ(phiJ(Axy(x)))
    % x = Axyi(phiJi(AJi(y)))
    % i have  phiJiAJiX 
    % just need to apply Axyi
    AxyiphiJiAjiX = Axy_(1,1)*phiJiAJiX + Axy_(1,2)*phiJiAJiY + Axy_(1,3);
    AxyiphiJiAjiY = Axy_(2,1)*phiJiAJiX + Axy_(2,2)*phiJiAJiY + Axy_(2,3);
    out = single(cat(4,AxyiphiJiAjiX-XJ,AxyiphiJiAjiY-YJ, zeros(size(AxyiphiJiAjiY))));
    write_vtk_image(xJ{f},yJ{f},zJ_write,out,[outdir 'input_to_registered_displacement_' fname_ '.vtk'],'input_to_registered_displacement');

    
    
%     %%
    % and now we need the deformation
    % do it exactly the same as above, but use identity
    % first apply the 2D affine (actually use identity now)
    BJ = eye(3);
    AJiX = BJ(1,1)*XJ + BJ(1,2)*YJ + BJ(1,3);
    AJiY = BJ(2,1)*XJ + BJ(2,2)*YJ + BJ(2,3);
    AJiZ = zJ(f); % identity
    
    % now apply 2D diffeo
    F = griddedInterpolant({yVJ,xVJ}, (phiJinvx-XVJ)*0, 'linear','nearest');
    phiJiAJiX = F(AJiY,AJiX) + AJiX;
    F = griddedInterpolant({yVJ,xVJ}, (phiJinvy-YVJ)*0, 'linear','nearest');
    phiJiAJiY = F(AJiY,AJiX) + AJiY;
    phiJiAJiZ = AJiZ; % identity
    
    % now apply the affine
    % it should be called Ai, not Bi
    B = inv(Axyz);
    AxyziPhiJiAJiX = B(1,1)*phiJiAJiX + B(1,2)*phiJiAJiY + B(1,3)*phiJiAJiZ + B(1,4);
    AxyziPhiJiAJiY = B(2,1)*phiJiAJiX + B(2,2)*phiJiAJiY + B(2,3)*phiJiAJiZ + B(2,4);
    AxyziPhiJiAJiZ = B(3,1)*phiJiAJiX + B(3,2)*phiJiAJiY + B(3,3)*phiJiAJiZ + B(3,4);
    
    % now apply the diffeo
    F = griddedInterpolant({yV,xV,zV}, phiinvx-XV, 'linear','nearest');
    phiiAxyziPhiJiAJiX = F(AxyziPhiJiAJiY,AxyziPhiJiAJiX,AxyziPhiJiAJiZ) + AxyziPhiJiAJiX;
    F = griddedInterpolant({yV,xV,zV}, phiinvy-YV, 'linear','nearest');
    phiiAxyziPhiJiAJiY = F(AxyziPhiJiAJiY,AxyziPhiJiAJiX,AxyziPhiJiAJiZ) + AxyziPhiJiAJiY;
    F = griddedInterpolant({yV,xV,zV}, phiinvz-ZV, 'linear','nearest');
    phiiAxyziPhiJiAJiZ = F(AxyziPhiJiAJiY,AxyziPhiJiAJiX,AxyziPhiJiAJiZ) + AxyziPhiJiAJiZ;    
    
%     % a nicer variable name 
%     phiiAxyziX = phiiAxyziPhiJiAJiX;
%     phiiAxyziY = phiiAxyziPhiJiAJiY;
%     phiiAxyziZ = phiiAxyziPhiJiAJiZ;
    
    
    
    
    
%     %%
    % now we want a deformation that includes straightening
    if save_qc
        for t = 1 : length(template_names)
            % if the template is an allen annotation, we do it with
            % outlines
            
            segalpha = 0.25;
            F = griddedInterpolant({yI{t},xI{t},zI{t}},I{t},'nearest','nearest');
            Seg = F(phiiAxyziPhiJiAJiY, phiiAxyziPhiJiAJiX, phiiAxyziPhiJiAJiZ);
            [Seg_x,Seg_y] = gradient(Seg);
            Seg_contour = Seg_x~=0 | Seg_y~=0;
            % dilate it
            Seg_contour_d = (convn(Seg_contour,ones(5),'same')~=0) - Seg_contour;
            
            
            danfigure(5);
            if ~isempty(strfind(template_names{t},'annotation'))
                %             SegInd = mod(Seg,256)+1;
                %             SegRGB = cat(3,reshape(colors(SegInd,1),size(Seg)),...
                %                 reshape(colors(SegInd,2),size(Seg)),...
                %                 reshape(colors(SegInd,3),size(Seg)));
                %             imagesc(xJ{f},yJ{f},SegRGB*segalpha + Jrecon*(1-segalpha))
                % plot the contour instead
                Jshow = Jrecon;
                for c = 1 : 3
                    tmp = Jshow(:,:,c);
                    tmp(Seg_contour~=0) = 1;
                    tmp(Seg_contour_d~=0) = 0;
                    Jshow(:,:,c) = tmp;
                end
                imagesc(xJ{f},yJ{f},Jshow)
                
            else
                
                % otherwise, if not an annotation, we do the following
%                 imagesc(xJ{f},yJ{f},bsxfun(@plus,Seg/max(Seg(:))*segalpha, Jrecon*(1-segalpha)))
                
                
%                 J1 = mean(Jrecon,3);
%                 J1 = J1 - min(J1(:));
%                 J1 = J1 / (max(J1(:)) - min(J1(:)));
%                 
%                 J2 = mean(Seg,3);
%                 J2 = J2 - min(J2(:));
%                 J2 = J2 / (max(J2(:)) - min(J2(:)));
  
                qlim = [0.01,0.99];
                J1 = mean(Jrecon,3);
                clim = quantile(J1(:),qlim);
                J1 = (J1 - clim(1))/diff(clim);
                
                J2 = mean(Seg,3);
                clim = quantile(J2(:),qlim);
                J2 = (J2 - clim(1))/diff(clim);
                
                imagesc(xJ{f},yJ{f},cat(3,J1,J2,J1))
                
            end
            title(['z = ' num2str(zJ(f))])
            axis image;
            xlabel x;
            ylabel y;
            set(gca,'xlim',5000*[-1,1],'ylim',5000*[-1 1]);
            [directory_, filename_, extension_] = fileparts(files{f});
            saveas(5,[outdir filename_ '_preview_' num2str(t) '_straight.png'])
        end
    end
    
    
    %% 
    % output the transformation that was used to deform the labels
    % this is registered to atlas
    out = single(cat(4,phiiAxyziPhiJiAJiX-XJ,phiiAxyziPhiJiAJiY-YJ, phiiAxyziPhiJiAJiZ-zJ(f)));
    write_vtk_image(xJ{f},yJ{f},zJ_write,out,[outdir 'registered_to_atlas_displacement_' fname_ '.vtk'],'registered_to_atlas_displacement');
    
    
    
    
    %%
    % last is we need a grid
    % I will use isocontours on phiiAxyziPhiJiAJiX
    % note Y and Z are important
%     hold on;
%     contour(xJ{f},yJ{f},phiiAxyziY,[-6000 : 500 : 6000],'k');
%     contour(xJ{f},yJ{f},phiiAxyziZ,[-6000 : 500 : 6000],'k');
%     contour(xJ{f},yJ{f},phiiAxyziX,[-6000 : 500 : 6000],'k'); 
% % note deformation out of plane spans many slices
%     hold off;
    


    
    %% 
    % now do it again with the detjac instead of the seg
    F = griddedInterpolant({yV,xV,zV},detjac,'linear','nearest');
    distortion = F(phiiAxyziPhiJiAJiY, phiiAxyziPhiJiAJiX, phiiAxyziPhiJiAJiZ);
    write_vtk_image(xJ{f},yJ{f},zJ,single(distortion),[outdir 'atlas_to_registered_detjac_' fname_ '.vtk'],'atlas_to_registered_detjac')

    
    
    %%
    
    drawnow;

    
end % of loop over files
