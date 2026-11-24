create or replace force view it.av_tar_deb_envios as
select decode(e.descripcion,
       -- Formato BANCARD
       'BANCARD',
	   lpad(nvl(fua_obt_cta_ficticia(t.nro_cuenta, t.nro_bin),pag_sue.Fu_cod_cuenta(t.nro_cuenta)),10,'0') ||  --Cuenta 10 - SDBIN8TDD-1 Obt Cta Ficticia
                 --lpad(pag_sue.Fu_cod_cuenta(t.nro_cuenta),10,'0')|| -- 10-nro cuenta
       2 || -- tipo cuenta  1= C.ahorro  2= C.Cte.
       decode(c.cod_moneda,pag_gen.fu_obt_mon_local,'600','840')|| -- 3-moneda
       t.adherente|| -- 2-adherente
       lpad( t.nro_emision, 2, '0' ) ||  -- 2-nro de emision
       lpad( ltrim( to_char( decode( t.tip_envio, 'R', nvl( t.cod_ofi_origen, c.cod_oficina ), c.cod_oficina ) ) ), 2, '0' ) || -- 2-oficina
       p.tipo|| -- 1-tipo Persona
       REPLACE(REPLACE(rpad( t.embozado, 26, ' ' ),CHR(13),' '),CHR(10),' ') || -- 26-embozado
       REPLACE(REPLACE(rpad(ltrim(rtrim(nvl(substr(f.pri_nombre,1,20),' '))),20,' '),CHR(13),' '),CHR(10),' ') || -- 20-Primer Nombre
       REPLACE(REPLACE(nvl(rpad(ltrim(rtrim(substr(f.seg_nombre,1,20))),20,' '),rpad(' ',20,' ')),CHR(13),' '),CHR(10),' ') || -- 20-Segundo Nombre
       REPLACE(REPLACE(rpad(ltrim(rtrim(nvl(substr(f.pri_apellido,1,20),' '))),20,' '),CHR(13),' '),CHR(10),' ') || -- 20-Primer Apellido
       REPLACE(REPLACE(nvl(rpad(ltrim(rtrim(substr(f.seg_apellido,1,20))),20,' '),rpad(' ',20,' ')),CHR(13),' '),CHR(10),' ') || -- 20-Segundo Apellido
       rpad(' ',30,' ')|| -- 30-razon social
       lpad( to_char( t.fec_vencimiento, 'YYYYMM' ), 6, '0' ) || -- 6-vencimiento
       REPLACE(REPLACE(REPLACE(rpad( nvl(decode( t.tip_envio, 'D', substr(b.direccion ||decode(b.numero,null,'',' '||numero)||nvl(' '||b.dir_lateral,' ')||nvl(decode(b.edificio,null,'',' Edf '||b.edificio),' ')||nvl(decode(b.piso,null,'',' Pso '||b.piso),' ')||nvl(decode(b.departamento,null,'',' Dto '||b.departamento),' '),1,60), 'R', r.descripcion, NULL ),o.descripcion), 60, ' ' ),CHR(13),' '),CHR(10),' '),CHR(9),' ') || -- direccion   60
       rpad( nvl(decode( t.tip_envio, 'D', ci.descripcion, 'R', r.descripcion ),o.descripcion), 40, ' ' ) || -- 40-localidad 35
       rpad(nvl(bt.telefono,'021'),25,' ')|| -- 25-telefono
       decode(p.tipo,'F',decode(p.cod_tip_documento,1,'CIP',2,'CAD',3,'PAS','   '),'   ')|| -- 3-Tipo Documento
       rpad(p.nro_documento,16,' ')|| -- 16-Número de documento/RUC
       --fug_obt_parentes(t.cod_ent_procesadora,'FOR_COM_EMBOZADO')|| -- 6-Codigo de Formato de Embozado
       rpad(fue_obt_des_refcodes('TIP_TAR_DEBITO',t.tip_tar_debito),6,' ')|| -- 6-Codigo de Formato de Embozado
       rpad(ROW_NUMBER() OVER (ORDER BY t.cod_persona),3,' ')|| -- 3-Nro. De Secuencia(Orden de Imp)
       rpad(ROW_NUMBER() OVER (ORDER BY t.cod_persona),7,' ')|| -- 7-Sub nro. De Secuencia(Orden de Imp)
       decode(t.nro_emision,'01','0',fua_obt_tip_renovacion(t.nro_cuenta,t.adherente,t.nro_emision, t.nro_bin))/*|| -- 1-estado: 0-alta, 1-Reemplazo, 2-Renovacion, 3-Baja   -- Tipo de acción a realizar
       lpad(t.nro_cuenta,15,'0')||  -- cuenta de banco
       rpad(' ',26,' ')  -- Empresa de la tarjeta*/
       ) registro,
       --
       t.nro_cuenta nro_cuenta,
       t.embozado embozado,
       t.adherente adherente,
       rtrim( t.nro_emision ) nro_emision,
       t.cod_persona cod_persona,
       lpad( substr( to_char( nvl( t.cod_ofi_origen, c.cod_oficina ) ), 1, 2 ), 2, '0' ) tip_tarjeta,
       t.fec_envio fec_envio,
       decode( t.tip_envio, 'R', lpad( substr( to_char( nvl( t.cod_ofi_origen, c.cod_oficina ) ), 1, 2 ), 2, '0' ) ) cod_ofi_origen,
       decode( c.cod_moneda, pag_gen.fu_obt_mon_local, '00', '01' ) cod_mon_numerico,
       c.cod_modalidad cod_modalidad,
       t.rowid fila,
       t.cod_ent_procesadora,
       e.descripcion,
       t.cod_est_solicitud,
       t.nro_lote, t.ide_reg_lote
   from ba_oficinas o,
        ba_ciudades ci,
        ba_personas p,
        ba_per_fisicas f,
        ah_tar_debitos t,
        cc_cta_corrientes c,
        ba_direcciones b,
        ba_telefonos bt,
        ge_dir_retenciones r,
        ge_entes e
  where t.cod_est_solicitud = 5     --- cambie de 3 q pone en el cierre
    and c.nro_cuenta = t.nro_cuenta
    and c.estado IN( 'N', 'A', 'I','S')  ---- lo de abajo para traer descripcion de direccion envio
    and p.cod_persona = t.cod_persona
    and p.cod_persona = f.cod_persona
    and r.cod_dir_retencion(+) = t.referencia
    and b.cod_persona(+) = t.cod_persona
    and b.cod_direccion(+) = t.referencia
    and bt.cod_persona(+) = p.cod_persona
    and bt.principal(+) = 'S'
    and o.cod_oficina(+)  = c.cod_oficina
    and ci.cod_pais(+)    = b.cod_pais
    and ci.cod_ciudad(+)  = b.cod_ciudad
    and e.cod_ente = t.cod_ent_procesadora
    and e.tipo = 'TA'
union
select decode(e.descripcion,
       -- Formato BANCARD
       'BANCARD', lpad(nvl(fua_obt_cta_ficticia(t.nro_cuenta, t.nro_bin),pag_sue.Fu_cod_cuenta(t.nro_cuenta)),10,'0') ||
                  --lpad(pag_sue.Fu_cod_cuenta(t.nro_cuenta),10,'0')|| -- 10-nro cuenta
       2 || -- tipo cuenta  1= C.ahorro  2= C.Cte.
       decode(c.cod_moneda,pag_gen.fu_obt_mon_local,'600','840')|| -- 3-moneda
       t.adherente|| -- 2-adherente
       lpad( t.nro_emision, 2, '0' ) ||  -- 2-nro de emision
       lpad( ltrim( to_char( decode( t.tip_envio, 'R', nvl( t.cod_ofi_origen, c.cod_oficina ), c.cod_oficina ) ) ), 2, '0' ) || -- 2-oficina
       p.tipo|| -- 1-tipo Persona
       REPLACE(REPLACE(rpad( t.embozado, 26, ' ' ),CHR(13),' '),CHR(10),' ') || -- 26-embozado
       rpad(' ',20,' ')|| -- 20-Primer Nombre
       rpad(' ',20,' ')|| -- 20-Segundo Nombre
       rpad(' ',20,' ')|| -- 20-Primer Apellido
       rpad(' ',20,' ')|| -- 20-Segundo Apellido
       rpad(substr(j.raz_social,1,30),30,' ')|| -- 30-razon social
       lpad( to_char( t.fec_vencimiento, 'YYYYMM' ), 6, '0' ) || -- 6-vencimiento
       REPLACE(REPLACE(REPLACE(rpad( nvl(decode( t.tip_envio, 'D', substr(b.direccion ||decode(b.numero,null,'',' '||numero)||nvl(' '||b.dir_lateral,' ')||nvl(decode(b.edificio,null,'',' Edf '||b.edificio),' ')||nvl(decode(b.piso,null,'',' Pso '||b.piso),' ')||nvl(decode(b.departamento,null,'',' Dto '||b.departamento),' '),1,60), 'R', r.descripcion, NULL ),o.descripcion), 60, ' ' ),CHR(13),' '),CHR(10),' '),CHR(9),' ') || -- direccion   60
       rpad( nvl(decode( t.tip_envio, 'D', ci.descripcion, 'R', r.descripcion ),o.descripcion), 40, ' ' ) || -- 40-localidad 35
       rpad(nvl(bt.telefono,'021'),25,' ')|| -- 25-telefono
       decode(p.tipo,'F',decode(p.cod_tip_documento,1,'CIP',2,'CAD',3,'PAS','   '),'   ')|| -- 3-Tipo Documento
       rpad(p.nro_documento,16,' ')|| -- 16-Número de documento/RUC
       --fug_obt_parentes(t.cod_ent_procesadora,'FOR_COM_EMBOZADO')|| -- 6-Codigo de Formato de Embozado
       rpad(fue_obt_des_refcodes('TIP_TAR_DEBITO',t.tip_tar_debito),6,' ')|| -- 6-Codigo de Formato de Embozado
       rpad(ROW_NUMBER() OVER (ORDER BY t.cod_persona),3,' ')|| -- 3-Nro. De Secuencia(Orden de Imp)
       rpad(ROW_NUMBER() OVER (ORDER BY t.cod_persona),7,' ')|| -- 7-Sub nro. De Secuencia(Orden de Imp)
       decode(t.nro_emision,'01','0',fua_obt_tip_renovacion(t.nro_cuenta,t.adherente,t.nro_emision, t.nro_bin))/*|| -- 1-estado: 0-alta, 1-Reemplazo, 2-Renovacion, 3-Baja   -- Tipo de acción a realizar
       lpad(t.nro_cuenta,15,'0')||  -- cuenta de banco
       rpad(' ',26,' ')  -- Empresa de la tarjeta
       */) registro,
       --
       t.nro_cuenta nro_cuenta,
       t.embozado embozado,
       t.adherente adherente,
       rtrim( t.nro_emision ) nro_emision,
       t.cod_persona cod_persona,
       lpad( substr( to_char( nvl( t.cod_ofi_origen, c.cod_oficina ) ), 1, 2 ), 2, '0' ) tip_tarjeta,
       t.fec_envio fec_envio,
       decode( t.tip_envio, 'R', lpad( substr( to_char( nvl( t.cod_ofi_origen, c.cod_oficina ) ), 1, 2 ), 2, '0' ) ) cod_ofi_origen,
       decode( c.cod_moneda, pag_gen.fu_obt_mon_local, '00', '01' ) cod_mon_numerico,
       c.cod_modalidad cod_modalidad,
       t.rowid fila,
       t.cod_ent_procesadora,
       e.descripcion,
       t.cod_est_solicitud,
       t.nro_lote, t.ide_reg_lote
   from ba_oficinas o,
        ba_ciudades ci,
        ba_personas p,
        ba_per_juridicas j,
        ah_tar_debitos t,
        cc_cta_corrientes c,
        ba_direcciones b,
        ba_telefonos bt,
        ge_dir_retenciones r,
        ge_entes e
  where t.cod_est_solicitud = 5   --- cambie de 3 q pone en el cierre
    and c.nro_cuenta = t.nro_cuenta
    and c.estado IN( 'N', 'A', 'I','S')  ---- lo de abajo para traer descripcion de direccion envio
    and p.cod_persona = t.cod_persona
    and p.cod_persona = j.cod_persona
    and r.cod_dir_retencion(+) = t.referencia
    and b.cod_persona(+) = t.cod_persona
    and b.cod_direccion(+) = t.referencia
    and bt.cod_persona(+) = p.cod_persona
    and bt.principal(+) = 'S'
    and o.cod_oficina(+)  = c.cod_oficina
    and ci.cod_pais(+)    = b.cod_pais
    and ci.cod_ciudad(+)  = b.cod_ciudad
    and e.cod_ente = t.cod_ent_procesadora
    and e.tipo = 'TA'
union
select decode(e.descripcion,
       -- Formato BANCARD
       'BANCARD',lpad(nvl(fua_obt_cta_ficticia(t.nro_cuenta, t.nro_bin),pag_sue.Fu_cod_cuenta(t.nro_cuenta)),10,'0') ||
       	        --lpad(pag_sue.Fu_cod_cuenta(t.nro_cuenta),10,'0')|| -- 10-nro cuenta
       1 || -- tipo cuenta  1= C.Cte.  2= C.Ahorro
       decode(v.cod_moneda,pag_gen.fu_obt_mon_local,'600','840')|| -- 3-moneda
       t.adherente|| -- 2-adherente
       lpad( t.nro_emision, 2, '0' ) ||  -- 2-nro de emision
       lpad( ltrim( to_char( decode( t.tip_envio, 'R', nvl( t.cod_ofi_origen, v.cod_oficina ), v.cod_oficina ) ) ), 2, '0' ) || -- 2-oficina
       p.tipo|| -- 1-tipo Persona
       REPLACE(REPLACE(rpad( t.embozado, 26, ' ' ),CHR(13),' '),CHR(10),' ') || -- 26-embozado
       REPLACE(REPLACE(rpad(ltrim(rtrim(nvl(substr(f.pri_nombre,1,20),' '))),20,' '),CHR(13),' '),CHR(10),' ')|| -- 20-Primer Nombre
       REPLACE(REPLACE(nvl(rpad(ltrim(rtrim(substr(f.seg_nombre,1,20))),20,' '),rpad(' ',20,' ')),CHR(13),' '),CHR(10),' ')|| -- 20-Segundo Nombre
       REPLACE(REPLACE(rpad(ltrim(rtrim(nvl(substr(f.pri_apellido,1,20),' '))),20,' '),CHR(13),' '),CHR(10),' ')|| -- 20-Primer Apellido
       REPLACE(REPLACE(nvl(rpad(ltrim(rtrim(substr(f.seg_apellido,1,20))),20,' '),rpad(' ',20,' ')),CHR(13),' '),CHR(10),' ')|| -- 20-Segundo Apellido
       rpad(' ',30,' ')|| -- 30-razon social
       lpad( to_char( t.fec_vencimiento, 'YYYYMM' ), 6, '0' ) || -- 6-vencimiento
       REPLACE(REPLACE(REPLACE(rpad( nvl(decode( t.tip_envio, 'D', substr(b.direccion ||decode(b.numero,null,'',' '||numero)||nvl(' '||b.dir_lateral,' ')||nvl(decode(b.edificio,null,'',' Edf '||b.edificio),' ')||nvl(decode(b.piso,null,'',' Pso '||b.piso),' ')||nvl(decode(b.departamento,null,'',' Dto '||b.departamento),' '),1,60), 'R', r.descripcion, NULL ),o.descripcion), 60, ' ' ),CHR(13),' '),CHR(10),' '),CHR(9),' ') || -- direccion   60
       rpad( nvl(decode( t.tip_envio, 'D', ci.descripcion, 'R', r.descripcion ),o.descripcion), 40, ' ' ) || -- 40-localidad 35
       rpad(nvl(bt.telefono,'021'),25,' ')|| -- 25-telefono
       decode(p.tipo,'F',decode(p.cod_tip_documento,1,'CIP',2,'CAD',3,'PAS','   '),'   ')|| -- 3-Tipo Documento
       rpad(p.nro_documento,16,' ')|| -- 16-Número de documento/RUC
       --fug_obt_parentes(t.cod_ent_procesadora,'FOR_COM_EMBOZADO')|| -- 6-Codigo de Formato de Embozado
       rpad(fue_obt_des_refcodes('TIP_TAR_DEBITO',t.tip_tar_debito),6,' ')|| -- 6-Codigo de Formato de Embozado
       rpad(ROW_NUMBER() OVER (ORDER BY t.cod_persona),3,' ')|| -- 3-Nro. De Secuencia(Orden de Imp)
       rpad(ROW_NUMBER() OVER (ORDER BY t.cod_persona),7,' ')|| -- 7-Sub nro. De Secuencia(Orden de Imp)
       decode(t.nro_emision,'01','0',fua_obt_tip_renovacion(t.nro_cuenta,t.adherente,t.nro_emision, t.nro_bin))/*|| -- 1-estado: 0-alta, 1-Reemplazo, 2-Renovacion, 3-Baja   -- Tipo de acción a realizar
       lpad(t.nro_cuenta,15,'0')||  -- cuenta de banco
       rpad(' ',26,' ')  -- Empresa de la tarjeta*/
       ) registro,
       --
       t.nro_cuenta nro_cuenta,
       t.embozado embozado,
       t.adherente adherente,
       rtrim( t.nro_emision ) nro_emision,
       t.cod_persona cod_persona,
       lpad( substr( to_char( nvl( t.cod_ofi_origen, v.cod_oficina ) ), 1, 2 ), 2, '0' ) tip_tarjeta,
       t.fec_envio fec_envio,
       decode( t.tip_envio, 'R', lpad( substr( to_char( nvl( t.cod_ofi_origen, v.cod_oficina ) ), 1, 2 ), 2, '0' ) ) cod_ofi_origen,
       decode( v.cod_moneda, pag_gen.fu_obt_mon_local, '00', '01' ) cod_mon_numerico,
       v.cod_modalidad cod_modalidad,
       t.rowid fila,
       t.cod_ent_procesadora,
       e.descripcion,
       t.cod_est_solicitud,
       t.nro_lote, t.ide_reg_lote
  from ba_oficinas o,
       ba_ciudades ci,
       ba_personas p,
       ba_per_fisicas f,
       ah_tar_debitos t,
       ah_cta_vistas v,
       ba_direcciones b,
       ba_telefonos bt,
       ge_dir_retenciones r,
       ge_entes e
 where t.cod_est_solicitud = 5   -- a enviar
   and v.nro_cuenta = t.nro_cuenta
   and v.estado IN( 'N', 'A', 'I','S' )   ---- lo de abajo para traer descripcion de direccion envio
   and p.cod_persona = t.cod_persona
   and p.cod_persona = f.cod_persona
   and r.cod_dir_retencion(+) = t.referencia
   and b.cod_persona(+) = t.cod_persona
   and b.cod_direccion(+) = t.referencia
   and bt.cod_persona(+) = p.cod_persona
   and bt.principal(+) = 'S'
   and o.cod_oficina(+)  = v.cod_oficina
   and ci.cod_pais(+)    = b.cod_pais
   and ci.cod_ciudad(+)  = b.cod_ciudad
   and e.cod_ente = t.cod_ent_procesadora
   and e.tipo = 'TA'
union all
select lpad(nvl(fua_obt_cta_ficticia(t.nro_cuenta, t.nro_bin),pag_sue.Fu_cod_cuenta(t.nro_cuenta)),10,'0') ||
       -- lpad(pag_sue.Fu_cod_cuenta(t.nro_cuenta),10,'0')|| -- 10-nro cuenta
       1 ||  -- tipo cuenta  1= C.Cte.  2= C.Ahorro
       decode(v.cod_moneda,'GS','600','840')|| -- 3-moneda
       t.adherente|| -- 2-adherente
       lpad( t.nro_emision, 2, '0' ) ||  -- 2-nro de emision
       lpad( ltrim( to_char( decode( t.tip_envio, 'R', nvl( t.cod_ofi_origen, v.cod_oficina ), v.cod_oficina ) ) ), 2, '0' ) || -- oficina
       p.tipo|| -- 1-tipo Persona
       REPLACE(REPLACE(rpad( t.embozado, 26, ' ' ),CHR(13),' '),CHR(10),' ')|| -- 26-embozado
       rpad(' ',20,' ')|| -- 20-Primer Nombre
       rpad(' ',20,' ')|| -- 20-Segundo Nombre
       rpad(' ',20,' ')|| -- 20-Primer Apellido
       rpad(' ',20,' ')|| -- 20-Segundo Apellido
       rpad(substr(j.raz_social,1,30),30,' ')|| -- 30-razon social
       lpad( to_char( t.fec_vencimiento, 'YYYYMM' ), 6, '0' ) || -- 6-vencimiento
       REPLACE(REPLACE(REPLACE(rpad( nvl(decode( t.tip_envio, 'D', substr(b.direccion ||decode(b.numero,null,'',' '||numero)||nvl(' '||b.dir_lateral,' ')||nvl(decode(b.edificio,null,'',' Edf '||b.edificio),' ')||nvl(decode(b.piso,null,'',' Pso '||b.piso),' ')||nvl(decode(b.departamento,null,'',' Dto '||b.departamento),' '),1,60), 'R', r.descripcion, NULL ),o.descripcion), 60, ' ' ),CHR(13),' '),CHR(10),' '),CHR(9),' ') || -- direccion   60
       rpad( nvl(decode( t.tip_envio, 'D', ci.descripcion, 'R', r.descripcion ),o.descripcion), 40, ' ' ) || -- 40-localidad 35
       rpad(nvl(bt.telefono,'021'),25,' ')|| -- 25-telefono
       rpad(' ',3,' ')||  -- 3-Tipo Documento
       rpad(substr(p.nro_documento,1,16),16,' ')|| -- 16-Número de documento/RUC
       --fug_obt_parentes(t.cod_ent_procesadora,'FOR_EMP_EMBOZADO')|| -- 6-Codigo de Formato de Embozado
       rpad(fue_obt_des_refcodes('TIP_TAR_DEBITO',t.tip_tar_debito),6,' ')|| -- 6-Codigo de Formato de Embozado
       rpad(ROW_NUMBER() OVER (ORDER BY t.cod_persona),3,' ')|| -- 3-Nro. De Secuencia(Orden de Imp)
       rpad(ROW_NUMBER() OVER (ORDER BY t.cod_persona),7,' ')|| -- 7-Sub nro. De Secuencia(Orden de Imp)
       decode(t.nro_emision,'01','0',fua_obt_tip_renovacion(t.nro_cuenta,t.adherente,t.nro_emision, t.nro_bin)) /*||-- 1-estado: 0-alta, 1-Reemplazo, 2-Renovacion, 3-Baja   -- Tipo de acción a realizar
       lpad(t.nro_cuenta,15,'0')||  -- cuenta de banco
       rpad(' ',26,' ')  -- Empresa de la tarjeta*/
       registro,
       t.nro_cuenta nro_cuenta,
       t.embozado embozado,
       t.adherente adherente,
       rtrim( t.nro_emision ) nro_emision,
       t.cod_persona cod_persona,
       lpad( substr( to_char( nvl( t.cod_ofi_origen, v.cod_oficina ) ), 1, 2 ), 2, '0' ) tip_tarjeta,
       t.fec_envio fec_envio,
       decode( t.tip_envio, 'R', lpad( substr( to_char( nvl( t.cod_ofi_origen, v.cod_oficina ) ), 1, 2 ), 2, '0' ) ) cod_ofi_origen,
       decode( v.cod_moneda, pag_gen.fu_obt_mon_local, '00', '01' ) cod_mon_numerico,
       v.cod_modalidad cod_modalidad,
       t.rowid fila,
       t.cod_ent_procesadora,
       e.descripcion,
       t.cod_est_solicitud,
       t.nro_lote, t.ide_reg_lote
  from ba_oficinas o,
       ba_ciudades ci,
       ba_personas p,
       ba_per_juridicas j,
       ah_tar_debitos t,
       ah_cta_vistas v,
       ba_direcciones b,
       ba_telefonos bt,
       ge_dir_retenciones r,
       ge_entes e
 where t.cod_est_solicitud = 5   -- a enviar
   and v.nro_cuenta = t.nro_cuenta
   and v.estado IN( 'N', 'A', 'I','S' )   ---- lo de abajo para traer descripcion de direccion envio
   and p.cod_persona = t.cod_persona
   and p.cod_persona = j.cod_persona
   and r.cod_dir_retencion(+) = t.referencia
   and b.cod_persona(+) = t.cod_persona
   and b.cod_direccion(+) = t.referencia
   and bt.cod_persona(+) = p.cod_persona
   and bt.principal(+) = 'S'
   and o.cod_oficina(+)  = v.cod_oficina
   and ci.cod_pais(+)    = b.cod_pais
   and ci.cod_ciudad(+)  = b.cod_ciudad
   and e.cod_ente = t.cod_ent_procesadora
   and e.tipo = 'TA'
union
select decode(e.descripcion,
       -- Formato BANCARD
       'BANCARD',
       lpad(nvl(fua_obt_cta_ficticia(t.nro_cuenta, t.nro_bin),pag_sue.Fu_cod_cuenta(t.nro_cuenta)),10,'0') ||
       --lpad(pag_sue.Fu_cod_cuenta(t.nro_cuenta),10,'0')|| -- 10-nro cuenta
       2 || -- tipo cuenta  1= C.ahorro  2= C.Cte.
       decode(c.cod_moneda,pag_gen.fu_obt_mon_local,'600','840')|| -- 3-moneda
       t.adherente|| -- 2-adherente
       lpad( t.nro_emision, 2, '0' ) ||  -- 2-nro de emision
       lpad( ltrim( to_char( decode( t.tip_envio, 'R', nvl( t.cod_ofi_origen, c.cod_oficina ), c.cod_oficina ) ) ), 2, '0' ) || -- 2-oficina
       p.tipo|| -- 1-tipo Persona
       REPLACE(REPLACE(rpad( t.embozado, 26, ' ' ),CHR(13),' '),CHR(10),' ') || -- 26-embozado
       REPLACE(REPLACE(rpad(ltrim(rtrim(nvl(substr(f.pri_nombre,1,20),' '))),20,' '),CHR(13),' '),CHR(10),' ')|| -- 20-Primer Nombre
       REPLACE(REPLACE(nvl(rpad(ltrim(rtrim(substr(f.seg_nombre,1,20))),20,' '),rpad(' ',20,' ')),CHR(13),' '),CHR(10),' ')|| -- 20-Segundo Nombre
       REPLACE(REPLACE(rpad(ltrim(rtrim(nvl(substr(f.pri_apellido,1,20),' '))),20,' '),CHR(13),' '),CHR(10),' ')|| -- 20-Primer Apellido
       REPLACE(REPLACE(nvl(rpad(ltrim(rtrim(substr(f.seg_apellido,1,20))),20,' '),rpad(' ',20,' ')),CHR(13),' '),CHR(10),' ')|| -- 20-Segundo Apellido
       rpad(' ',30,' ')|| -- 30-razon social
       lpad( to_char( t.fec_vencimiento, 'YYYYMM' ), 6, '0' ) || -- 6-vencimiento
       REPLACE(REPLACE(REPLACE(rpad( nvl(decode( t.tip_envio, 'D', substr(b.direccion ||decode(b.numero,null,'',' '||numero)||nvl(' '||b.dir_lateral,' ')||nvl(decode(b.edificio,null,'',' Edf '||b.edificio),' ')||nvl(decode(b.piso,null,'',' Pso '||b.piso),' ')||nvl(decode(b.departamento,null,'',' Dto '||b.departamento),' '),1,60), 'R', r.descripcion, NULL ),o.descripcion), 60, ' ' ),CHR(13),' '),CHR(10),' '),CHR(9),' ') || -- direccion   60
       rpad( nvl(decode( t.tip_envio, 'D', ci.descripcion, 'R', r.descripcion ),o.descripcion), 40, ' ' ) || -- 40-localidad 35
       rpad(nvl(bt.telefono,'021'),25,' ')|| -- 25-telefono
       decode(p.tipo,'F',decode(p.cod_tip_documento,1,'CIP',2,'CAD',3,'PAS','   '),'   ')|| -- 3-Tipo Documento
       rpad(p.nro_documento,16,' ')|| -- 16-Número de documento/RUC
       --fug_obt_parentes(t.cod_ent_procesadora,'FOR_COM_EMBOZADO')|| -- 6-Codigo de Formato de Embozado
       rpad(fue_obt_des_refcodes('TIP_TAR_DEBITO',t.tip_tar_debito),6,' ')|| -- 6-Codigo de Formato de Embozado
       rpad(ROW_NUMBER() OVER (ORDER BY t.cod_persona),3,' ')|| -- 3-Nro. De Secuencia(Orden de Imp)
       rpad(ROW_NUMBER() OVER (ORDER BY t.cod_persona),7,' ')|| -- 7-Sub nro. De Secuencia(Orden de Imp)
       3/*|| -- Baja
       lpad(t.nro_cuenta,15,'0')||  -- cuenta de banco
       rpad(' ',26,' ')  -- Empresa de la tarjeta*/
       ) registro,
       --
       t.nro_cuenta nro_cuenta,
       t.embozado embozado,
       t.adherente adherente,
       rtrim( t.nro_emision ) nro_emision,
       t.cod_persona cod_persona,
       lpad( substr( to_char( nvl( t.cod_ofi_origen, c.cod_oficina ) ), 1, 2 ), 2, '0' ) tip_tarjeta,
       t.fec_envio fec_envio,
       decode( t.tip_envio, 'R', lpad( substr( to_char( nvl( t.cod_ofi_origen, c.cod_oficina ) ), 1, 2 ), 2, '0' ) ) cod_ofi_origen,
       decode( c.cod_moneda, pag_gen.fu_obt_mon_local, '00', '01' ) cod_mon_numerico,
       c.cod_modalidad cod_modalidad,
       t.rowid fila,
       t.cod_ent_procesadora,
       e.descripcion,
       t.cod_est_solicitud,
       t.nro_lote, t.ide_reg_lote
   from ba_oficinas o,
        ba_ciudades ci,
        ba_personas p,
        ba_per_fisicas f,
        ah_tar_debitos t,
        cc_cta_corrientes c,
        ba_direcciones b,
        ba_telefonos bt,
        ge_dir_retenciones r,
        ge_entes e
  where t.cod_est_solicitud = 15
    and c.nro_cuenta = t.nro_cuenta
    and c.estado IN( 'N', 'A', 'I','S')  ---- lo de abajo para traer descripcion de direccion envio
    and p.cod_persona = t.cod_persona
    and p.cod_persona = f.cod_persona
    and r.cod_dir_retencion(+) = t.referencia
    and b.cod_persona(+) = t.cod_persona
    and b.cod_direccion(+) = t.referencia
    and bt.cod_persona(+) = p.cod_persona
    and bt.principal(+) = 'S'
    and o.cod_oficina(+)  = c.cod_oficina
    and ci.cod_pais(+)    = b.cod_pais
    and ci.cod_ciudad(+)  = b.cod_ciudad
    and e.cod_ente = t.cod_ent_procesadora
    and e.tipo = 'TA'
union
select decode(e.descripcion,
       -- Formato BANCARD
       'BANCARD',
       lpad(nvl(fua_obt_cta_ficticia(t.nro_cuenta, t.nro_bin),pag_sue.Fu_cod_cuenta(t.nro_cuenta)),10,'0') ||
        --lpad(pag_sue.Fu_cod_cuenta(t.nro_cuenta),10,'0')|| -- 10-nro cuenta
       --decode(v.cod_moneda,pag_gen.fu_obt_mon_local,2,4)|| --tipo cuenta
       1 || -- tipo cuenta  1= C.Cte.  2= C.Ahorro
       decode(v.cod_moneda,pag_gen.fu_obt_mon_local,'600','840')|| -- 3-moneda
       t.adherente|| -- 2-adherente
       lpad( t.nro_emision, 2, '0' ) ||  -- 2-nro de emision
       lpad( ltrim( to_char( decode( t.tip_envio, 'R', nvl( t.cod_ofi_origen, v.cod_oficina ), v.cod_oficina ) ) ), 2, '0' ) || -- 2-oficina
       p.tipo|| -- 1-tipo Persona
       REPLACE(REPLACE(rpad( t.embozado, 26, ' ' ),CHR(13),' '),CHR(10),' ') || -- 26-embozado
       rpad(ltrim(rtrim(nvl(substr(f.pri_nombre,1,20),' '))),20,' ')|| -- 20-Primer Nombre
       nvl(rpad(ltrim(rtrim(substr(f.seg_nombre,1,20))),20,' '),rpad(' ',20,' '))|| -- 20-Segundo Nombre
       rpad(ltrim(rtrim(nvl(substr(f.pri_apellido,1,20),' '))),20,' ')|| -- 20-Primer Apellido
       nvl(rpad(ltrim(rtrim(substr(f.seg_apellido,1,20))),20,' '),rpad(' ',20,' '))|| -- 20-Segundo Apellido
       rpad(' ',30,' ')|| -- 30-razon social
       lpad( to_char( t.fec_vencimiento, 'YYYYMM' ), 6, '0' ) || -- 6-vencimiento
       REPLACE(REPLACE(REPLACE(rpad( nvl(decode( t.tip_envio, 'D', substr(b.direccion ||decode(b.numero,null,'',' '||numero)||nvl(' '||b.dir_lateral,' ')||nvl(decode(b.edificio,null,'',' Edf '||b.edificio),' ')||nvl(decode(b.piso,null,'',' Pso '||b.piso),' ')||nvl(decode(b.departamento,null,'',' Dto '||b.departamento),' '),1,60), 'R', r.descripcion, NULL ),o.descripcion), 60, ' ' ),CHR(13),' '),CHR(10),' '),CHR(9),' ') || -- direccion   60
       rpad( nvl(decode( t.tip_envio, 'D', ci.descripcion, 'R', r.descripcion ),o.descripcion), 40, ' ' ) || -- 40-localidad 35
       rpad(nvl(bt.telefono,'021'),25,' ')|| -- 25-telefono
       decode(p.tipo,'F',decode(p.cod_tip_documento,1,'CIP',2,'CAD',3,'PAS','   '),'   ')|| -- 3-Tipo Documento
       rpad(p.nro_documento,16,' ')|| -- 16-Número de documento/RUC
       --fug_obt_parentes(t.cod_ent_procesadora,'FOR_COM_EMBOZADO')|| -- 6-Codigo de Formato de Embozado
       rpad(fue_obt_des_refcodes('TIP_TAR_DEBITO',t.tip_tar_debito),6,' ')|| -- 6-Codigo de Formato de Embozado
       rpad(ROW_NUMBER() OVER (ORDER BY t.cod_persona),3,' ')|| -- 3-Nro. De Secuencia(Orden de Imp)
       rpad(ROW_NUMBER() OVER (ORDER BY t.cod_persona),7,' ')|| -- 7-Sub nro. De Secuencia(Orden de Imp)
       3--baja
       ) registro,
       --
       t.nro_cuenta nro_cuenta,
       t.embozado embozado,
       t.adherente adherente,
       rtrim( t.nro_emision ) nro_emision,
       t.cod_persona cod_persona,
       lpad( substr( to_char( nvl( t.cod_ofi_origen, v.cod_oficina ) ), 1, 2 ), 2, '0' ) tip_tarjeta,
       t.fec_envio fec_envio,
       decode( t.tip_envio, 'R', lpad( substr( to_char( nvl( t.cod_ofi_origen, v.cod_oficina ) ), 1, 2 ), 2, '0' ) ) cod_ofi_origen,
       decode( v.cod_moneda, pag_gen.fu_obt_mon_local, '00', '01' ) cod_mon_numerico,
       v.cod_modalidad cod_modalidad,
       t.rowid fila,
       t.cod_ent_procesadora,
       e.descripcion,
       t.cod_est_solicitud,
       t.nro_lote, t.ide_reg_lote
  from ba_oficinas o,
       ba_ciudades ci,
       ba_personas p,
       ba_per_fisicas f,
       ah_tar_debitos t,
       ah_cta_vistas v,
       ba_direcciones b,
       ba_telefonos bt,
       ge_dir_retenciones r,
       ge_entes e
 where t.cod_est_solicitud = 15
   and v.nro_cuenta = t.nro_cuenta
   and v.estado IN( 'N', 'A', 'I','S' )   ---- lo de abajo para traer descripcion de direccion envio
   and p.cod_persona = t.cod_persona
   and p.cod_persona = f.cod_persona
   and r.cod_dir_retencion(+) = t.referencia
   and b.cod_persona(+) = t.cod_persona
   and b.cod_direccion(+) = t.referencia
   and bt.cod_persona(+) = p.cod_persona
   and bt.principal(+) = 'S'
   and o.cod_oficina(+)  = v.cod_oficina
   and ci.cod_pais(+)    = b.cod_pais
   and ci.cod_ciudad(+)  = b.cod_ciudad
   and e.cod_ente = t.cod_ent_procesadora
   and e.tipo = 'TA'
union
select decode(e.descripcion,
       -- Formato BANCARD
       'BANCARD', lpad(nvl(fua_obt_cta_ficticia(t.nro_cuenta, t.nro_bin),pag_sue.Fu_cod_cuenta(t.nro_cuenta)),10,'0') ||
       --lpad(pag_sue.Fu_cod_cuenta(t.nro_cuenta),10,'0')|| -- 10-nro cuenta
       2 || -- tipo cuenta  1= C.ahorro  2= C.Cte.
       --decode(c.cod_moneda,pag_gen.fu_obt_mon_local,1,3)|| --tipo cuenta
       decode(c.cod_moneda,pag_gen.fu_obt_mon_local,'600','840')|| -- 3-moneda
       t.adherente|| -- 2-adherente
       lpad( t.nro_emision, 2, '0' ) ||  -- 2-nro de emision
       lpad( ltrim( to_char( decode( t.tip_envio, 'R', nvl( t.cod_ofi_origen, c.cod_oficina ), c.cod_oficina ) ) ), 2, '0' ) || -- 2-oficina
       p.tipo|| -- 1-tipo Persona
       REPLACE(REPLACE(rpad( t.embozado, 26, ' ' ),CHR(13),' '),CHR(10),' ') || -- 26-embozado
       rpad(' ',20,' ')|| -- 20-Primer Nombre
       rpad(' ',20,' ')|| -- 20-Segundo Nombre
       rpad(' ',20,' ')|| -- 20-Primer Apellido
       rpad(' ',20,' ')|| -- 20-Segundo Apellido
       rpad(substr(j.raz_social,1,30),30,' ')|| -- 30-razon social
       lpad( to_char( t.fec_vencimiento, 'YYYYMM' ), 6, '0' ) || -- 6-vencimiento
       rpad( nvl(decode( t.tip_envio, 'D', substr(b.direccion ||decode(b.numero,null,'',' '||numero)||nvl(' '||b.dir_lateral,' '),1,60), 'R', r.descripcion, NULL ),o.descripcion), 60, ' ' ) || -- direccion   60
       REPLACE(REPLACE(REPLACE(rpad( nvl(decode( t.tip_envio, 'D', substr(b.direccion ||decode(b.numero,null,'',' '||numero)||nvl(' '||b.dir_lateral,' ')||nvl(decode(b.edificio,null,'',' Edf '||b.edificio),' ')||nvl(decode(b.piso,null,'',' Pso '||b.piso),' ')||nvl(decode(b.departamento,null,'',' Dto '||b.departamento),' '),1,60), 'R', r.descripcion, NULL ),o.descripcion), 60, ' ' ),CHR(13),' '),CHR(10),' '),CHR(9),' ') || -- direccion   60
       rpad( nvl(decode( t.tip_envio, 'D', ci.descripcion, 'R', r.descripcion ),o.descripcion), 40, ' ' ) || -- 40-localidad 35
       rpad(nvl(bt.telefono,'021'),25,' ')|| -- 25-telefono
       decode(p.tipo,'F',decode(p.cod_tip_documento,1,'CIP',2,'CAD',3,'PAS','   '),'   ')|| -- 3-Tipo Documento
       rpad(p.nro_documento,16,' ')|| -- 16-Número de documento/RUC
       --fug_obt_parentes(t.cod_ent_procesadora,'FOR_COM_EMBOZADO')|| -- 6-Codigo de Formato de Embozado
       rpad(fue_obt_des_refcodes('TIP_TAR_DEBITO',t.tip_tar_debito),6,' ')|| -- 6-Codigo de Formato de Embozado
       rpad(ROW_NUMBER() OVER (ORDER BY t.cod_persona),3,' ')|| -- 3-Nro. De Secuencia(Orden de Imp)
       rpad(ROW_NUMBER() OVER (ORDER BY t.cod_persona),7,' ')|| -- 7-Sub nro. De Secuencia(Orden de Imp)
       3 -- baja
       ) registro,
       --
       t.nro_cuenta nro_cuenta,
       t.embozado embozado,
       t.adherente adherente,
       rtrim( t.nro_emision ) nro_emision,
       t.cod_persona cod_persona,
       lpad( substr( to_char( nvl( t.cod_ofi_origen, c.cod_oficina ) ), 1, 2 ), 2, '0' ) tip_tarjeta,
       t.fec_envio fec_envio,
       decode( t.tip_envio, 'R', lpad( substr( to_char( nvl( t.cod_ofi_origen, c.cod_oficina ) ), 1, 2 ), 2, '0' ) ) cod_ofi_origen,
       decode( c.cod_moneda, pag_gen.fu_obt_mon_local, '00', '01' ) cod_mon_numerico,
       c.cod_modalidad cod_modalidad,
       t.rowid fila,
       t.cod_ent_procesadora,
       e.descripcion,
       t.cod_est_solicitud,
       t.nro_lote, t.ide_reg_lote
   from ba_oficinas o,
        ba_ciudades ci,
        ba_personas p,
        ba_per_juridicas j,
        ah_tar_debitos t,
        cc_cta_corrientes c,
        ba_direcciones b,
        ba_telefonos bt,
        ge_dir_retenciones r,
        ge_entes e
  where t.cod_est_solicitud = 15
    and c.nro_cuenta = t.nro_cuenta
    and c.estado IN( 'N', 'A', 'I','S')  ---- lo de abajo para traer descripcion de direccion envio
    and p.cod_persona = t.cod_persona
    and p.cod_persona = j.cod_persona
    and r.cod_dir_retencion(+) = t.referencia
    and b.cod_persona(+) = t.cod_persona
    and b.cod_direccion(+) = t.referencia
    and bt.cod_persona(+) = p.cod_persona
    and bt.principal(+) = 'S'
    and o.cod_oficina(+)  = c.cod_oficina
    and ci.cod_pais(+)    = b.cod_pais
    and ci.cod_ciudad(+)  = b.cod_ciudad
    and e.cod_ente = t.cod_ent_procesadora
    and e.tipo = 'TA'
union
select lpad(nvl(fua_obt_cta_ficticia(t.nro_cuenta, t.nro_bin),pag_sue.Fu_cod_cuenta(t.nro_cuenta)),10,'0') ||
       --lpad(pag_sue.Fu_cod_cuenta(t.nro_cuenta),10,'0')|| -- 10-nro cuenta
       --decode(v.cod_moneda,pag_gen.fu_obt_mon_local,2,4)|| --tipo cuenta
       1 ||  -- tipo cuenta  1= C.Cte.  2= C.Ahorro
       decode(v.cod_moneda,'GS','600','840')|| -- 3-moneda
       t.adherente|| -- 2-adherente
       lpad( t.nro_emision, 2, '0' ) ||  -- 2-nro de emision
       lpad( ltrim( to_char( decode( t.tip_envio, 'R', nvl( t.cod_ofi_origen, v.cod_oficina ), v.cod_oficina ) ) ), 2, '0' ) || -- oficina
       p.tipo|| -- 1-tipo Persona
       REPLACE(REPLACE(rpad( t.embozado, 26, ' ' ),CHR(13),' '),CHR(10),' ') || -- 26-embozado
       rpad(' ',20,' ')|| -- 20-Primer Nombre
       rpad(' ',20,' ')|| -- 20-Segundo Nombre
       rpad(' ',20,' ')|| -- 20-Primer Apellido
       rpad(' ',20,' ')|| -- 20-Segundo Apellido
       rpad(substr(j.raz_social,1,30),30,' ')|| -- 30-razon social
       lpad( to_char( t.fec_vencimiento, 'YYYYMM' ), 6, '0' ) || -- 6-vencimiento
       rpad( nvl(decode( t.tip_envio, 'D', substr(b.direccion ||decode(b.numero,null,'',' '||numero)||nvl(' '||b.dir_lateral,' '),1,60), 'R', r.descripcion, NULL ),o.descripcion), 60, ' ' ) || -- direccion   60
       REPLACE(REPLACE(REPLACE(rpad( nvl(decode( t.tip_envio, 'D', substr(b.direccion ||decode(b.numero,null,'',' '||numero)||nvl(' '||b.dir_lateral,' ')||nvl(decode(b.edificio,null,'',' Edf '||b.edificio),' ')||nvl(decode(b.piso,null,'',' Pso '||b.piso),' ')||nvl(decode(b.departamento,null,'',' Dto '||b.departamento),' '),1,60), 'R', r.descripcion, NULL ),o.descripcion), 60, ' ' ),CHR(13),' '),CHR(10),' '),CHR(9),' ') || -- direccion   60
       rpad( nvl(decode( t.tip_envio, 'D', ci.descripcion, 'R', r.descripcion ),o.descripcion), 40, ' ' ) || -- 40-localidad 35
       rpad(nvl(bt.telefono,'021'),25,' ')|| -- 25-telefono
       rpad(' ',3,' ')||  -- 3-Tipo Documento
       rpad(substr(p.nro_documento,1,16),16,' ')|| -- 16-Número de documento/RUC
       --fug_obt_parentes(t.cod_ent_procesadora,'FOR_EMP_EMBOZADO')|| -- 6-Codigo de Formato de Embozado
       rpad(fue_obt_des_refcodes('TIP_TAR_DEBITO',t.tip_tar_debito),6,' ')|| -- 6-Codigo de Formato de Embozado
       rpad(ROW_NUMBER() OVER (ORDER BY t.cod_persona),3,' ')|| -- 3-Nro. De Secuencia(Orden de Imp)
       rpad(ROW_NUMBER() OVER (ORDER BY t.cod_persona),7,' ')|| -- 7-Sub nro. De Secuencia(Orden de Imp)
       3--baja
       registro,
       t.nro_cuenta nro_cuenta,
       t.embozado embozado,
       t.adherente adherente,
       rtrim( t.nro_emision ) nro_emision,
       t.cod_persona cod_persona,
       lpad( substr( to_char( nvl( t.cod_ofi_origen, v.cod_oficina ) ), 1, 2 ), 2, '0' ) tip_tarjeta,
       t.fec_envio fec_envio,
       decode( t.tip_envio, 'R', lpad( substr( to_char( nvl( t.cod_ofi_origen, v.cod_oficina ) ), 1, 2 ), 2, '0' ) ) cod_ofi_origen,
       decode( v.cod_moneda, pag_gen.fu_obt_mon_local, '00', '01' ) cod_mon_numerico,
       v.cod_modalidad cod_modalidad,
       t.rowid fila,
       t.cod_ent_procesadora,
       e.descripcion,
       t.cod_est_solicitud,
       t.nro_lote, t.ide_reg_lote
  from ba_oficinas o,
       ba_ciudades ci,
       ba_personas p,
       ba_per_juridicas j,
       ah_tar_debitos t,
       ah_cta_vistas v,
       ba_direcciones b,
       ba_telefonos bt,
       ge_dir_retenciones r,
       ge_entes e
 where t.cod_est_solicitud  = 15
   and v.nro_cuenta = t.nro_cuenta
   and v.estado IN( 'N', 'A', 'I','S' )   ---- lo de abajo para traer descripcion de direccion envio
   and p.cod_persona = t.cod_persona
   and p.cod_persona = j.cod_persona
   and r.cod_dir_retencion(+) = t.referencia
   and b.cod_persona(+) = t.cod_persona
   and b.cod_direccion(+) = t.referencia
   and bt.cod_persona(+) = p.cod_persona
   and bt.principal(+) = 'S'
   and o.cod_oficina(+)  = v.cod_oficina
   and ci.cod_pais(+)    = b.cod_pais
   and ci.cod_ciudad(+)  = b.cod_ciudad
   and e.cod_ente = t.cod_ent_procesadora
   and e.tipo = 'TA'
;

