-- create table
create table it.pr_pre_che_roga
(
  nro_oferta          number(10) not null,
  nro_doc_solicitante varchar2(20),
  cod_per_solicitante varchar2(10),
  nro_doc_invitado    varchar2(20),
  cod_per_invitado    varchar2(10),
  fec_oferta          date,
  fec_vencimiento     date,
  mto_total           number(18,2),
  mto_proyecto        number(18,2),
  mto_equipamiento    number(18,2),
  mto_cuota           number(18,2),
  can_cuotas          number(5),
  cod_moneda          varchar2(3),
  tip_producto        varchar2(100),
  ubi_vivienda        varchar2(100),
  nom_proyecto        varchar2(100),
  tip_vivienda        varchar2(100),
  sub_tip_vivienda    varchar2(100),
  constructora        varchar2(100),
  detalle_1           varchar2(100),
  detalle_2           varchar2(100),
  detalle_3           varchar2(100),
  detalle_4           varchar2(100),
  detalle_5           varchar2(100),
  estado              varchar2(50) default 'P',
  inv_acepto          varchar2(1) default 'N',
  nro_solicitud       number,
  dimension           varchar2(10),
  can_dormitorios     number,
  cod_oficina         number(3),
  cod_usu_oficial     varchar2(10),
  tip_amortizacion    varchar2(1),
  cod_modalidad       number(3),
  cod_rub_economico   varchar2(6),
  mot_estado          varchar2(500),
  unidad              varchar2(15),
  pto_equilibrio      varchar2(15),
  tip_garantia        varchar2(20),
  mto_garantia        number(18,2),
  mto_notario         number(18,2),
  mto_tasacion        number(18,2),
  mto_adm_gastos      number(18,2),
  mto_cuo_contruccion number(18,2),
  equipamiento        varchar2(20),
  usu_insercion       varchar2(10) default substr(user,1,10),
  fec_insercion       date default sysdate,
  usu_modificacion    varchar2(10) default substr(user,1,10),
  fec_modificacion    date default sysdate
)
tablespace it_data
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64k
    next 1m
    minextents 1
    maxextents unlimited
  );
-- add comments to the table 
comment on table it.pr_pre_che_roga
  is 'Contiene los datos de Ofertas Che Roga.';
-- add comments to the columns 
comment on column it.pr_pre_che_roga.nro_oferta
  is 'Numero de oferta.';
comment on column it.pr_pre_che_roga.nro_doc_solicitante
  is 'Nro. Documento Solicitante.';
comment on column it.pr_pre_che_roga.cod_per_solicitante
  is 'Codigo Persona Solicitante.';
comment on column it.pr_pre_che_roga.nro_doc_invitado
  is 'Nro. Documento Invitado.';
comment on column it.pr_pre_che_roga.cod_per_invitado
  is 'Codigo Persona Invitado.';
comment on column it.pr_pre_che_roga.fec_oferta
  is 'Fecha de solicitud.';
comment on column it.pr_pre_che_roga.fec_vencimiento
  is 'Fecha de vencimiento.';
comment on column it.pr_pre_che_roga.mto_total
  is 'Monto Total.';
comment on column it.pr_pre_che_roga.mto_proyecto
  is 'Monto Proyecto.';
comment on column it.pr_pre_che_roga.mto_equipamiento
  is 'Monto Equipamiento.';
comment on column it.pr_pre_che_roga.mto_cuota
  is 'Monto Cuota.';
comment on column it.pr_pre_che_roga.can_cuotas
  is 'Cantidad de Cuotas.';
comment on column it.pr_pre_che_roga.cod_moneda
  is 'Codigo de Moneda.';
comment on column it.pr_pre_che_roga.tip_producto
  is 'Tipo de Producto.';
comment on column it.pr_pre_che_roga.ubi_vivienda
  is 'Ubicacion de la vivienda.';
comment on column it.pr_pre_che_roga.nom_proyecto
  is 'Nombre del Proyecto.';
comment on column it.pr_pre_che_roga.tip_vivienda
  is 'Tipo de vivienta.';
comment on column it.pr_pre_che_roga.sub_tip_vivienda
  is 'Sub Tipo de vivienda.';
comment on column it.pr_pre_che_roga.constructora
  is 'Constructora.';
comment on column it.pr_pre_che_roga.detalle_1
  is 'Detalle 1.';
comment on column it.pr_pre_che_roga.detalle_2
  is 'Detalle 2.';
comment on column it.pr_pre_che_roga.detalle_3
  is 'Detalle 3.';
comment on column it.pr_pre_che_roga.detalle_4
  is 'Detalle 4.';
comment on column it.pr_pre_che_roga.detalle_5
  is 'Detalle 5.';
comment on column it.pr_pre_che_roga.estado
  is 'Estado oferta: (P = Pendiente, A = Pendiente analizar calif. credito, I = Aprobado IFI, E = Pendiente punto de equilibrio, F = Pendiente aprobación AFD, D = Aprobado AFD, C = Pendiente continuidad cliente, V = Avanzar solicitud, X = Cancelado por el cliente, Y = Pendiente desembolso AFD, Z = Desembolsado AFD, W = Desembolsado IFI, U = Continuar solicitud, G = Pendiente gestion AFD, B = Pendiente desembolso BNF, N = Desembolsado BNF, H = Cancelado MUVH, J = Rechazado IFI, S= Cancelado 90 dias.)';
comment on column it.pr_pre_che_roga.inv_acepto
  is 'Invitado acepto Oferta.';
comment on column it.pr_pre_che_roga.nro_solicitud
  is 'Numero de solicitud.';
comment on column it.pr_pre_che_roga.dimension
  is 'Dimension.';
comment on column it.pr_pre_che_roga.can_dormitorios
  is 'Cantidad de dormitorios.';
comment on column it.pr_pre_che_roga.cod_oficina
  is 'Oficina.';
comment on column it.pr_pre_che_roga.cod_usu_oficial
  is 'Usuario Oficial. ';
comment on column it.pr_pre_che_roga.tip_amortizacion
  is 'Tipo de Amortizacion.';
comment on column it.pr_pre_che_roga.cod_modalidad
  is 'Codigo de Modalidad.';
comment on column it.pr_pre_che_roga.cod_rub_economico
  is 'Codigo Rubro Economico.';
comment on column it.pr_pre_che_roga.mot_estado
  is 'Motivo de Rechazo.';
comment on column it.pr_pre_che_roga.unidad
  is 'Unidad.';
comment on column it.pr_pre_che_roga.pto_equilibrio
  is 'Punto de Equilibrio.';
comment on column it.pr_pre_che_roga.tip_garantia
  is 'Tipo de garantia.';
comment on column it.pr_pre_che_roga.mto_garantia
  is 'Costo de la Fiducia de Garantía.';
comment on column it.pr_pre_che_roga.mto_notario
  is 'Costo de Notarios y Registros.';
comment on column it.pr_pre_che_roga.mto_tasacion
  is 'Tasación Obra Terminada.';
comment on column it.pr_pre_che_roga.mto_adm_gastos
  is 'Gastos Administrativos.';
comment on column it.pr_pre_che_roga.mto_cuo_contruccion
  is 'Monto de Cuotas del Periodo Constructivo.';
comment on column it.pr_pre_che_roga.equipamiento
  is 'Equipamiento.';
  comment on column it.pr_pre_che_roga.usu_insercion
  is 'Usuario que realizo la insercion';
comment on column it.pr_pre_che_roga.fec_insercion
  is 'Fecha en que se inserto el registro';
comment on column it.pr_pre_che_roga.usu_modificacion
  is 'Usuario que realizo la modificacion';
comment on column it.pr_pre_che_roga.fec_modificacion
  is 'Fecha en que se realizo la ultima modificacion';
-- create/recreate primary, unique and foreign key constraints 
alter table it.pr_pre_che_roga
  add constraint pk_pr_pre_che_roga primary key (nro_oferta)
  using index 
  tablespace it_ind
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64k
    next 1m
    minextents 1
    maxextents unlimited
  );
-- grant/revoke object privileges 
grant select, insert, update, delete on it.pr_pre_che_roga to it_temporal;
