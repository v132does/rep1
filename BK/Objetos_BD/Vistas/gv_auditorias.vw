CREATE OR REPLACE FORCE VIEW IT.GV_AUDITORIAS AS
SELECT a.tabla tabla,
nvl(b.comments,a.tabla) nom_tabla,
a.clave clave,
a.usuario usuario,
c.nombre nom_usuario,
a.fec_sistema fec_real,
a.fec_calendario fec_calendario,
decode(a.tip_novedad,'I','Inclusión','M','Modificación','E','Borrado') tipo,
a.origen origen,
nvl(d.descripcion,a.origen) nom_origen,
a.terminal equipo,
FUE_OBT_NOVEDAD(tip_novedad,a.detalle) detalle,
a.detalle det_original
from ba_programas d, ba_usuarios c, all_tab_comments b, ba_auditorias a
WHERE b.table_name(+) = a.tabla
and b.owner(+) = 'IT' and c.cod_usuario(+) = a.usuario
and d.cod_programa(+) = a.origen
union all
select a.tabla tabla,
nvl(b.comments,a.tabla) nom_tabla,
a.clave clave,
a.usuario usuario,
c.nombre nom_usuario,
a.fec_sistema fec_real,
a.fec_calendario fec_calendario,
decode(a.tip_novedad,'I','Inclusión','M','Modificación','E','Borrado') tipo,
a.origen origen,
nvl(d.descripcion,a.origen) nom_origen,
a.terminal equipo,
FUE_OBT_NOVEDAD(tip_novedad,a.detalle) detalle,
a.detalle det_original
from ba_programas d, ba_usuarios c, all_tab_comments b, ah_auditorias a
where b.table_name(+) = a.tabla
and b.owner(+) = 'IT' and c.cod_usuario(+) = a.usuario
and d.cod_programa(+) = a.origen
union all
select a.tabla tabla,
nvl(b.comments,a.tabla) nom_tabla,
a.clave clave,
a.usuario usuario,
c.nombre nom_usuario,
a.fec_sistema fec_real,
a.fec_calendario fec_calendario,
decode(a.tip_novedad,'I','Inclusión','M','Modificación','E','Borrado') tipo,
a.origen origen,
nvl(d.descripcion,a.origen) nom_origen,
a.terminal equipo,
FUE_OBT_NOVEDAD(tip_novedad,a.detalle) detalle,
a.detalle det_original
from ba_programas d, ba_usuarios c, all_tab_comments b, ap_auditorias a
where b.table_name(+) = a.tabla
and b.owner(+) = 'IT' and c.cod_usuario(+) = a.usuario
and d.cod_programa(+) = a.origen
union all
select a.tabla tabla,
nvl(b.comments,a.tabla) nom_tabla,
a.clave clave,
a.usuario usuario,
c.nombre nom_usuario,
a.fec_sistema fec_real,
a.fec_calendario fec_calendario,
decode(a.tip_novedad,'I','Inclusión','M','Modificación','E','Borrado') tipo,
a.origen origen,
nvl(d.descripcion,a.origen) nom_origen,
a.terminal equipo,
FUE_OBT_NOVEDAD(tip_novedad,a.detalle) detalle,
a.detalle det_original
from ba_programas d, ba_usuarios c, all_tab_comments b, cc_auditorias a
where b.table_name(+) = a.tabla
and b.owner(+) = 'IT' and c.cod_usuario(+) = a.usuario
and d.cod_programa(+) = a.origen
union all
select a.tabla tabla,
nvl(b.comments,a.tabla) nom_tabla,
a.clave clave,
a.usuario usuario,
c.nombre nom_usuario,
a.fec_sistema fec_real,
a.fec_calendario fec_calendario,
decode(a.tip_novedad,'I','Inclusión','M','Modificación','E','Borrado') tipo,
a.origen origen,
nvl(d.descripcion,a.origen) nom_origen,
a.terminal equipo,
FUE_OBT_NOVEDAD(tip_novedad,a.detalle) detalle,
a.detalle det_original
from ba_programas d, ba_usuarios c, all_tab_comments b, cb_auditorias a
where b.table_name(+) = a.tabla
and b.owner(+) = 'IT' and c.cod_usuario(+) = a.usuario
and d.cod_programa(+) = a.origen
union all
select a.tabla tabla,
nvl(b.comments,a.tabla) nom_tabla,
a.clave clave,
a.usuario usuario,
c.nombre nom_usuario,
a.fec_sistema fec_real,
a.fec_calendario fec_calendario,
decode(a.tip_novedad,'I','Inclusión','M','Modificación','E','Borrado') tipo,
a.origen origen,
nvl(d.descripcion,a.origen) nom_origen,
a.terminal equipo,
FUE_OBT_NOVEDAD(tip_novedad,a.detalle) detalle,
a.detalle det_original
from ba_programas d, ba_usuarios c, all_tab_comments b, cx_auditorias a
where b.table_name(+) = a.tabla
and b.owner(+) = 'IT' and c.cod_usuario(+) = a.usuario
and d.cod_programa(+) = a.origen
union all
select a.tabla tabla,
nvl(b.comments,a.tabla) nom_tabla,
a.clave clave,
a.usuario usuario,
c.nombre nom_usuario,
a.fec_sistema fec_real,
a.fec_calendario fec_calendario,
decode(a.tip_novedad,'I','Inclusión','M','Modificación','E','Borrado') tipo,
a.origen origen,
nvl(d.descripcion,a.origen) nom_origen,
a.terminal equipo,
FUE_OBT_NOVEDAD(tip_novedad,a.detalle) detalle,
a.detalle det_original
from ba_programas d, ba_usuarios c, all_tab_comments b, cj_auditorias a
where b.table_name(+) = a.tabla
and b.owner(+) = 'IT' and c.cod_usuario(+) = a.usuario
and d.cod_programa(+) = a.origen
union all
select a.tabla tabla,
nvl(b.comments,a.tabla) nom_tabla,
a.clave clave,
a.usuario usuario,
c.nombre nom_usuario,
a.fec_sistema fec_real,
a.fec_calendario fec_calendario,
decode(a.tip_novedad,'I','Inclusión','M','Modificación','E','Borrado') tipo,
a.origen origen,
nvl(d.descripcion,a.origen) nom_origen,
a.terminal equipo,
FUE_OBT_NOVEDAD(tip_novedad,a.detalle) detalle,
a.detalle det_original
from ba_programas d, ba_usuarios c, all_tab_comments b, cr_auditorias a
where b.table_name(+) = a.tabla
and b.owner(+) = 'IT' and c.cod_usuario(+) = a.usuario
and d.cod_programa(+) = a.origen
union all
select a.tabla tabla,
nvl(b.comments,a.tabla) nom_tabla,
a.clave clave,
a.usuario usuario,
c.nombre nom_usuario,
a.fec_sistema fec_real,
a.fec_calendario fec_calendario,
decode(a.tip_novedad,'I','Inclusión','M','Modificación','E','Borrado') tipo,
a.origen origen,
nvl(d.descripcion,a.origen) nom_origen,
a.terminal equipo,
FUE_OBT_NOVEDAD(tip_novedad,a.detalle) detalle,
a.detalle det_original
from ba_programas d, ba_usuarios c, all_tab_comments b, co_auditorias a
where b.table_name(+) = a.tabla
and b.owner(+) = 'IT' and c.cod_usuario(+) = a.usuario
and d.cod_programa(+) = a.origen
union all
select a.tabla tabla,
nvl(b.comments,a.tabla) nom_tabla,
a.clave clave,
a.usuario usuario,
c.nombre nom_usuario,
a.fec_sistema fec_real,
a.fec_calendario fec_calendario,
decode(a.tip_novedad,'I','Inclusión','M','Modificación','E','Borrado') tipo,
a.origen origen,
nvl(d.descripcion,a.origen) nom_origen,
a.terminal equipo,
FUE_OBT_NOVEDAD(tip_novedad,a.detalle) detalle,
a.detalle det_original
from ba_programas d, ba_usuarios c, all_tab_comments b, ge_auditorias a
where b.table_name(+) = a.tabla
and b.owner(+) = 'IT' and c.cod_usuario(+) = a.usuario
and d.cod_programa(+) = a.origen
union all
select a.tabla tabla,
nvl(b.comments,a.tabla) nom_tabla,
a.clave clave,
a.usuario usuario,
c.nombre nom_usuario,
a.fec_sistema fec_real,
a.fec_calendario fec_calendario,
decode(a.tip_novedad,'I','Inclusión','M','Modificación','E','Borrado') tipo,
a.origen origen,
nvl(d.descripcion,a.origen) nom_origen,
a.terminal equipo,
FUE_OBT_NOVEDAD(tip_novedad,a.detalle) detalle,
a.detalle det_original
from ba_programas d, ba_usuarios c, all_tab_comments b, lc_auditorias a
where b.table_name(+) = a.tabla
and b.owner(+) = 'IT' and c.cod_usuario(+) = a.usuario
and d.cod_programa(+) = a.origen
union all
select a.tabla tabla,
nvl(b.comments,a.tabla) nom_tabla,
a.clave clave,
a.usuario usuario,
c.nombre nom_usuario,
a.fec_sistema fec_real,
a.fec_calendario fec_calendario,
decode(a.tip_novedad,'I','Inclusión','M','Modificación','E','Borrado') tipo,
a.origen origen,
nvl(d.descripcion,a.origen) nom_origen,
a.terminal equipo,
FUE_OBT_NOVEDAD(tip_novedad,a.detalle) detalle,
a.detalle det_original
from ba_programas d, ba_usuarios c, all_tab_comments b, pr_auditorias a
where b.table_name(+) = a.tabla
and b.owner(+) = 'IT' and c.cod_usuario(+) = a.usuario
and d.cod_programa(+) = a.origen
union all
select a.tabla tabla,
nvl(b.comments,a.tabla) nom_tabla,
a.clave clave,
a.usuario usuario,
c.nombre nom_usuario,
a.fec_sistema fec_real,
a.fec_calendario fec_calendario,
decode(a.tip_novedad,'I','Inclusión','M','Modificación','E','Borrado') tipo,
a.origen origen,
nvl(d.descripcion,a.origen) nom_origen,
a.terminal equipo,
FUE_OBT_NOVEDAD(tip_novedad,a.detalle) detalle,
a.detalle det_original
from ba_programas d, ba_usuarios c, all_tab_comments b, ta_auditorias a
where b.table_name(+) = a.tabla
and b.owner(+) = 'IT' and c.cod_usuario(+) = a.usuario
and d.cod_programa(+) = a.origen
union all
select a.tabla tabla,
nvl(b.comments,a.tabla) nom_tabla,
a.clave clave,
a.usuario usuario,
c.nombre nom_usuario,
a.fec_sistema fec_real,
a.fec_calendario fec_calendario,
decode(a.tip_novedad,'I','Inclusión','M','Modificación','E','Borrado') tipo,
a.origen origen,
nvl(d.descripcion,a.origen) nom_origen,
a.terminal equipo,
FUE_OBT_NOVEDAD(tip_novedad,a.detalle) detalle,
a.detalle det_original
from ba_programas d, ba_usuarios c, all_tab_comments b, ge_auditorias_his a
where b.table_name(+) = a.tabla
and b.owner(+) = 'IT' and c.cod_usuario(+) = a.usuario
and d.cod_programa(+) = a.origen
union all
SELECT a.tabla tabla,
nvl(b.comments,a.tabla) nom_tabla,
a.clave clave,
a.usuario usuario,
c.nombre nom_usuario,
a.fec_sistema fec_real,
a.fec_calendario fec_calendario,
decode(a.tip_novedad,'I','Inclusión','M','Modificación','E','Borrado') tipo,
a.origen origen,
nvl(d.descripcion,a.origen) nom_origen,
a.terminal equipo,
FUE_OBT_NOVEDAD(tip_novedad,a.detalle) detalle,
a.detalle det_original
from ba_programas d, ba_usuarios c, all_tab_comments b, cs_auditorias a
WHERE b.table_name(+) = a.tabla
and b.owner(+) = 'IT' and c.cod_usuario(+) = a.usuario
and d.cod_programa(+) = a.origen
union all
SELECT a.tabla tabla,
nvl(b.comments,a.tabla) nom_tabla,
a.clave clave,
a.usuario usuario,
c.nombre nom_usuario,
a.fec_sistema fec_real,
a.fec_calendario fec_calendario,
decode(a.tip_novedad,'I','Inclusión','M','Modificación','E','Borrado') tipo,
a.origen origen,
nvl(d.descripcion,a.origen) nom_origen,
a.terminal equipo,
FUE_OBT_NOVEDAD(tip_novedad,a.detalle) detalle,
a.detalle det_original
from ba_programas d, ba_usuarios c, all_tab_comments b, md_auditorias a
WHERE b.table_name(+) = a.tabla
and b.owner(+) = 'IT' and c.cod_usuario(+) = a.usuario
and d.cod_programa(+) = a.origen
union all  ---Auditoria de Proveedores
select a.tabla tabla,
nvl(b.comments,a.tabla) nom_tabla,
a.clave clave,
a.usuario usuario,
c.nombre nom_usuario,
a.fec_sistema fec_real,
a.fec_calendario fec_calendario,
decode(a.tip_novedad,'I','Inclusión','M','Modificación','E','Borrado') tipo,
a.origen origen,
nvl(d.descripcion,a.origen) nom_origen,
a.terminal equipo,
FUE_OBT_NOVEDAD(tip_novedad,a.detalle) detalle,
a.detalle det_original
from ba_programas d, ba_usuarios c, all_tab_comments b, pv_auditorias a
where b.table_name(+) = a.tabla
and b.owner(+) = 'IT' and c.cod_usuario(+) = a.usuario
and d.cod_programa(+) = a.origen
union all  ---Auditoria de Suministros
select a.tabla tabla,
nvl(b.comments,a.tabla) nom_tabla,
a.clave clave,
a.usuario usuario,
c.nombre nom_usuario,
a.fec_sistema fec_real,
a.fec_calendario fec_calendario,
decode(a.tip_novedad,'I','Inclusión','M','Modificación','E','Borrado') tipo,
a.origen origen,
nvl(d.descripcion,a.origen) nom_origen,
a.terminal equipo,
FUE_OBT_NOVEDAD(tip_novedad,a.detalle) detalle,
a.detalle det_original
from ba_programas d, ba_usuarios c, all_tab_comments b, in_auditorias a
where b.table_name(+) = a.tabla
and b.owner(+) = 'IT' and c.cod_usuario(+) = a.usuario
and d.cod_programa(+) = a.origen
union all  ---Auditoria de Activo Fijo
select a.tabla tabla,
nvl(b.comments,a.tabla) nom_tabla,
a.clave clave,
a.usuario usuario,
c.nombre nom_usuario,
a.fec_sistema fec_real,
a.fec_calendario fec_calendario,
decode(a.tip_novedad,'I','Inclusión','M','Modificación','E','Borrado') tipo,
a.origen origen,
nvl(d.descripcion,a.origen) nom_origen,
a.terminal equipo,
FUE_OBT_NOVEDAD(tip_novedad,a.detalle) detalle,
a.detalle det_original
from ba_programas d, ba_usuarios c, all_tab_comments b, af_auditorias a
where b.table_name(+) = a.tabla
and b.owner(+) = 'IT' and c.cod_usuario(+) = a.usuario
and d.cod_programa(+) = a.origen
-- CRO-JM-11/2014: DYDMR-987
union all  ---Auditoria de Banca Electronica
select a.tabla tabla,
nvl(b.comments,a.tabla) nom_tabla,
a.clave clave,
a.usuario usuario,
c.nombre nom_usuario,
a.fec_sistema fec_real,
a.fec_calendario fec_calendario,
decode(a.tip_novedad,'I','Inclusión','M','Modificación','E','Borrado') tipo,
a.origen origen,
nvl(d.descripcion,a.origen) nom_origen,
a.terminal equipo,
FUE_OBT_NOVEDAD(tip_novedad,a.detalle) detalle,
a.detalle det_original
from ba_programas d, ba_usuarios c, all_tab_comments b, bw_auditorias a
where b.table_name(+) = a.tabla
and b.owner(+) = 'IT' and c.cod_usuario(+) = a.usuario
and d.cod_programa(+) = a.origen
;

