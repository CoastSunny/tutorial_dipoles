function vol = ft_prepare_headmodel(cfg, mri)
import external.fieldtrip.*;
% FT_PREPARE_HEADMODEL constructs a volume conduction model from
% the geometry of the head. The volume conduction model specifies how
% currents that are generated by sources in the brain, e.g. dipoles,
% are propagated through the tissue and how these result in externally
% measureable EEG potentials or MEG fields.
%
% This function takes care of all the preparatory steps in the
% construction of the volume conduction model and sets it up so that
% subsequent computations are efficient and fast.
%
% The input to this function is a geometrical description of the
% shape of the head. If you pass a segmented anatomical MRI as input,
% the geometry will be based on that.
%
% Use as
%   vol = ft_prepare_headmodel(cfg)
%   vol = ft_prepare_headmodel(cfg, mri)
%   vol = ft_prepare_headmodel(cfg, mesh)
% 
% The second input argument can be a surface mesh that was obtained from
% FT_PREPARE_MESH or a segmented anatomical MRI that was obtained from
% FT_VOLUMESEGMENT.
% The mesh can be provided optionally as the name of a surface file in cfg.hdmfile
%
% The configuration structure should contain:
%     cfg.method            string that specifies the forward solution, see below
%     cfg.conductivity      a number or a vector contining the conductivities
%                           of the compartments
% 
% Additionally, each of the following methods requires the custom cfg options:
% 
%  'bem_cp', 'bem_dipoli', 'bem_openmeeg' 
%     cfg.isolatedsource    (optional)
% 
%  'concentricspheres'
%     cfg.fitind            (optional)
% 
%  'localspheres'
%     cfg.grad   
%     cfg.feedback          (optional)
%     cfg.radius            (optional)
%     cfg.maxradius         (optional)
%     cfg.baseline          (optional)
% 
% 'halfspace'
%     cfg.point     
%     cfg.submethod         (optional)
%     
% 'simbio' , 'fns'
%     cfg.tissue      
%     cfg.tissueval 
%     cfg.tissuecond  
%     cfg.elec      
%     cfg.transform   
%     cfg.unit      
% 
% 'infinite_slab'
%     cfg.samplepoint
%     cfg.conductivity
% 
% FieldTrip implements a variety of forward solutions, some of
% them using external toolboxes or executables. Each of the forward
% solutions requires a set of configuration options which are listed below.
%
% For EEG the following methods are available
%   singlesphere
%   bem_asa
%   bem_cp
%   bem_dipoli
%   bem_openmeeg
%   concentricspheres
%   halfspace
%   infinite
%   infinite_slab
%
% For MEG the following methods are available
%   singlesphere
%   localspheres
%   singleshell
%   infinite

% Copyright (C) 2011, Cristiano Micheli, Jan-Mathijs Schoffelen
%
% $Log$

% FIXME list the options in the documentation to the function

ft_defaults

cfg = ft_checkconfig(cfg, 'trackconfig', 'on');
cfg = ft_checkconfig(cfg, 'required', 'method');
cfg = ft_checkconfig(cfg, 'deprecated', 'geom');

geometry = [];
if nargin>1 && ft_datatype(mri, 'volume') && ~strcmp(cfg.method,'fns')
  fprintf('computing the geometrical description from the segmented MRI\n');
%   mri = geometry;
%   clear geometry;

  % defaults
  cfg.smooth      = ft_getopt(cfg, 'smooth',      5);
  cfg.sourceunits = ft_getopt(cfg, 'sourceunits', 'cm');
  cfg.threshold   = ft_getopt(cfg, 'threshold',   0.5);
  cfg.numvertices = ft_getopt(cfg, 'numvertices', 4000);

  tmpcfg = [];
  tmpcfg.smooth       = cfg.smooth;
  tmpcfg.sourceunits  = cfg.sourceunits;
  tmpcfg.threshold    = cfg.threshold;
  tmpcfg.numvertices  = cfg.numvertices;

  % construct a surface-based geometry from the input MRI
  geometry = ft_prepare_mesh(tmpcfg, mri);
  
elseif nargin>1
  fprintf('using the specified geometrical description\n');
  geometry = mri;
end

% only cfg was specified, this is for backward compatibility
if isfield(cfg, 'geom') && nargin==1
  geometry = cfg.geom;
  cfg = rmfield(cfg, 'geom');
end

% the construction of the volume conductor model is performed below
switch cfg.method
  case 'bem_asa'
    cfg         = ft_checkconfig(cfg, 'required', 'hdmfile');
    cfg.hdmfile = ft_getopt(cfg, 'hdmfile', []);
    vol = ft_headmodel_bem_asa(cfg.hdmfile);
    
  case {'bem_cp' 'bem_dipoli' 'bem_openmeeg'}
    cfg.hdmfile        = ft_getopt(cfg, 'hdmfile', []);
    cfg.conductivity   = ft_getopt(cfg, 'conductivity',   []);
    cfg.isolatedsource = ft_getopt(cfg, 'isolatedsource', []);
    if strcmp(cfg.method,'bem_cp')
      funname = 'ft_headmodel_bemcp';
    elseif strcmp(cfg.method,'bem_dipoli')
      funname = 'ft_headmodel_bem_dipoli';
    else
      funname = 'ft_headmodel_bem_openmeeg';
    end
    if ~isempty(cfg.hdmfile)
      vol = feval(funname, [],'hdmfile',cfg.hdmfile,'conductivity',cfg.conductivity,'isolatedsource',cfg.isolatedsource);
    elseif ~isempty(geometry)
      bnd = geometry;
      for i=1:length(bnd)
        geom.bnd(i) = bnd(i);
      end
      vol = feval(funname, geom,'conductivity',cfg.conductivity,'isolatedsource',cfg.isolatedsource);
    else
      error('for cfg.method = %s, you need to supply a data mesh or a cfg.hdmfile', cfg.method);
    end
    
  case 'concentricspheres'
    cfg.conductivity   = ft_getopt(cfg, 'conductivity',   []);
    cfg.fitind         = ft_getopt(cfg, 'fitind', 1);
    vol = ft_headmodel_concentricspheres(geometry,'conductivity',cfg.conductivity,'fitind',cfg.fitind);
    
  case 'halfspace'
    cfg.point     = ft_getopt(cfg, 'point',     []);
    cfg.submethod = ft_getopt(cfg, 'submethod', []);
    cfg.conductivity = ft_getopt(cfg, 'conductivity',   []);
    vol = ft_headmodel_halfspace(geometry, cfg.point, 'conductivity',cfg.conductivity,'submethod',cfg.submethod);
    
  case 'infinite'
    vol = ft_headmodel_infinite;
    
  case 'localspheres'
    cfg.grad      = ft_getopt(cfg, 'grad',      []);
    if isempty(cfg.grad)
      error('for cfg.method = %s, you need to supply a cfg.grad structure', cfg.method);
    end
    cfg.feedback  = ft_getopt(cfg, 'feedback',  true);
    cfg.radius    = ft_getopt(cfg, 'radius',    8.5);
    cfg.maxradius = ft_getopt(cfg, 'maxradius', 20);
    cfg.baseline  = ft_getopt(cfg, 'baseline',  5);
    vol = ft_headmodel_localspheres(geometry,cfg.grad,'feedback',cfg.feedback,'radius',cfg.radius,'maxradius',cfg.maxradius,'baseline',cfg.baseline);
    
  case 'singleshell'
    vol = ft_headmodel_singleshell(geometry);
    
  case 'singlesphere'
    cfg.conductivity   = ft_getopt(cfg, 'conductivity',   []);
    if ~isempty(geometry)
    geometry = geometry.pnt;
    elseif ~isempty(cfg.hdmfile)
      geometry = ft_read_headshape(cfg.hdmfile);
      geometry = geometry.pnt;
    else
      error('no input available')
    end
    
    vol = ft_headmodel_singlesphere(geometry,'conductivity',cfg.conductivity);
    
  case {'simbio' 'fns'}
    cfg.tissue      = ft_getopt(cfg, 'tissue', []);
    cfg.tissueval   = ft_getopt(cfg, 'tissueval', []);
    cfg.tissuecond  = ft_getopt(cfg, 'tissuecond', []);
    cfg.elec        = ft_getopt(cfg, 'elec',  []);
    cfg.transform   = ft_getopt(cfg, 'transform',  []);
    cfg.unit        = ft_getopt(cfg, 'unit',  []);
    if length([cfg.tissue cfg.tissueval cfg.tissuecond cfg.elec cfg.transform cfg.unit])<6
      error('Not all the required fields have been provided, see help')
    end
    if strcmp(method,'simbio')
      funname = 'ft_headmodel_fem_simbio';
    else
      funname = 'ft_headmodel_fdm_fns';
    end
    vol = feval(funname,'tissue',cfg.tissue,'tissueval',cfg.tissueval, ...
                               'tissuecond',cfg.tissuecond,'sens',cfg.elec, ...
                               'transform',cfg.transform,'unit',cfg.unit); 
  case 'slab_monopole'
    if numel(geometry)==2
      geom1 = geometry(1);
      geom2 = geometry(2);
      P = ft_getopt(cfg, 'samplepoint');
      vol = ft_headmodel_slab(geom1,geom2,P,'sourcemodel','monopole');
    else
      error('geometry should be described by exactly 2 sets of points')
    end
    
  otherwise
    error('unsupported method "%s"', cfg.method);
end

% get the output cfg
cfg = ft_checkconfig(cfg, 'trackconfig', 'off', 'checksize', 'yes');

% FIXME should the output vol get a cfg?
