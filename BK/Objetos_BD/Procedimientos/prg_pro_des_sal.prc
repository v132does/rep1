CREATE OR REPLACE PROCEDURE IT.PRG_PRO_DES_SAL
 IS
v_fcdehoy    date;
v_hora       ge_movimientos.hora%type;
v_cdusuar    ge_movimientos.cod_usuario%type;
v_nro_sec    ge_movimientos.nro_secuencia%type := 0;

PROCEDURE LP_LIB_BLO_AV IS

  cursor BLOQUEOAV IS
    select gec.cod_modulo, gec.cod_modalidad, gec.cod_oficina,
           geb.nro_cuenta, geb.monto, geb.nro_documento, geb.cod_causa, geb.fec_fin
      from ge_bloqueos geb,
           ge_cuentas  gec
     where gec.cod_modulo   = 3
       and gec.cod_modalidad = 31
       and gec.nro_cuenta    = geb.nro_cuenta
       and geb.fec_fin is not null
       and geb.fec_fin < v_fcdehoy;

  v_cdmodul    ge_cuentas.cod_modulo%type;
  v_cdmodal    ge_cuentas.cod_modalidad%type;
  v_cdofici    ge_cuentas.cod_oficina%type;
  v_nrcuent    ge_bloqueos.nro_cuenta%type;
  v_vlbloqu    ge_bloqueos.monto%type;
  v_nrdocum    ge_bloqueos.nro_documento%type;
  v_cdcaubl    ge_bloqueos.cod_causa%type;
  v_fcfinal    ge_bloqueos.fec_fin%type;

BEGIN
  OPEN BLOQUEOAV;
  LOOP
     fetch BLOQUEOAV into V_CDMODUL, V_CDMODAL, V_CDOFICI,V_NRCUENT,
                          V_VLBLOQU, V_NRDOCUM, V_CDCAUBL,V_FCFINAL;
     exit when BLOQUEOAV%notfound;
    ---------------------------------------
    -- actualiza saldo bloqueado on line --
    ---------------------------------------
     update ah_cta_vistas
       set sal_bloqueado = nvl(sal_bloqueado,0) - v_vlbloqu
     where nro_cuenta  = v_nrcuent;

    -----------------------------------------------
    --  genera diario de movimientos             --
    -----------------------------------------------
     v_nro_sec := v_nro_sec + 1;
     insert into ge_movimientos
      (cod_usuario,hora,nro_secuencia,
       cod_modulo,cod_modalidad,cod_oficina,nro_cuenta,
       cod_moneda,fec_valor,fecha,cod_tra_padre,
       cod_transaccion,nro_documento,monto,estado,
       cod_causa,cod_ofi_origen,concepto,
       cod_tasa,val_tasa,reversado,cod_usu_reversion,
       hor_reversion,emi_aviso,protegido,cod_mod_padre,
       cod_mad_padre)
     select v_cdusuar,v_hora,v_nro_sec,v_cdmodul,v_cdmodal,v_cdofici,v_nrcuent,
            cod_moneda,v_fcfinal,v_fcdehoy,317,507,v_nrdocum,v_vlbloqu,'N',
            v_cdcaubl,v_cdofici,null,null, null, 'N',null,null,'N', 'N', v_cdmodul, v_cdmodal
       from ah_cta_vistas
      where nro_cuenta  = v_nrcuent;
  END LOOP;
  IF bloqueoav%rowcount > 0 THEN
------------------------------------------------------------------------
-- procesa para aquellos que tengan saldo bloqueado = 0 (av_slblool)  --
-- y estado igual a "S" (av_esctaol)                                  --
------------------------------------------------------------------------
-----------------------------------------------
--  genera diario de movimientos             --
-----------------------------------------------
    v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
    insert into ge_movimientos
      (cod_usuario,hora,nro_secuencia,
       cod_modulo,cod_modalidad,cod_oficina,nro_cuenta,
       cod_moneda,fec_valor,fecha,cod_tra_padre,
       cod_transaccion,est_cuenta,estado,cod_ofi_origen,
       reversado,emi_aviso,protegido,cod_mod_padre,
       cod_mad_padre)
    select v_cdusuar, v_hora, v_nro_sec + rownum,
      cod_modulo,cod_modalidad,cod_oficina,nro_cuenta,
      cod_moneda,v_fcdehoy,v_fcdehoy,317, 425,'N','N',v_cdofici,
      'N', 'N', 'N', cod_modulo,cod_modalidad
    from ah_cta_vistas
    where sal_bloqueado = 0
      and estado = 'S';

   update ah_cta_vistas
       set estado = 'N',
           fec_cam_estado = v_fcdehoy
     where sal_bloqueado = 0
       and estado = 'S';

    v_nro_sec := v_nro_sec + bloqueoav%rowcount;
  END IF;
  CLOSE bloqueoav;
exception
  when others then
     raise_application_error(-20000,'ERROR: en AV '||sqlerrm);
end;

PROCEDURE LP_LIB_BLO_CDA IS

  cursor BLOQUEOCDA IS
    select gec.cod_modulo, gec.cod_modalidad, gec.cod_oficina,
           geb.nro_cuenta, geb.monto, geb.nro_documento, geb.cod_causa, geb.fec_fin,
           geb.rowid v_rowid
      from ge_bloqueos geb,
           ge_cuentas  gec
     where gec.cod_modulo   = 3
       and gec.cod_modalidad IN (33,34,35)
       and gec.nro_cuenta   = geb.nro_cuenta
       and geb.fec_fin is not null
       and geb.fec_fin < v_fcdehoy;

  v_cdmodul    ge_cuentas.cod_modulo%type;
  v_cdmodal    ge_cuentas.cod_modalidad%type;
  v_cdofici    ge_cuentas.cod_oficina%type;
  v_nrcuent    ge_bloqueos.nro_cuenta%type;
  v_vlbloqu    ge_bloqueos.monto%type;
  v_nrdocum    ge_bloqueos.nro_documento%type;
  v_cdcaubl    ge_bloqueos.cod_causa%type;
  v_fcfinal    ge_bloqueos.fec_fin%type;
  v_rowid      varchar2(50);

BEGIN
  v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
  OPEN BLOQUEOCDA;
  LOOP
     fetch BLOQUEOCDA into V_CDMODUL, V_CDMODAL, V_CDOFICI,V_NRCUENT,
                           V_VLBLOQU, V_NRDOCUM, V_CDCAUBL,V_FCFINAL,
                           v_rowid;
     exit when BLOQUEOCDA%notfound;
    ---------------------------------------
    -- actualiza saldo bloqueado on line --
    ---------------------------------------
     update ah_cta_certificados
       set sal_bloqueado = nvl(sal_bloqueado,0) - v_vlbloqu
     where nro_cuenta  = v_nrcuent;

    -----------------------------------------------
    --  genera diario de movimientos             --
    -----------------------------------------------
     v_nro_sec := v_nro_sec + 1;
     insert into ge_movimientos
      (cod_usuario,hora,nro_secuencia,
       cod_modulo,cod_modalidad,cod_oficina,nro_cuenta,
       cod_moneda,fec_valor,fecha,cod_tra_padre,
       cod_transaccion,nro_documento,monto,estado,
       cod_causa,cod_ofi_origen,concepto,
       cod_tasa,val_tasa,reversado,cod_usu_reversion,
       hor_reversion,emi_aviso,protegido,cod_mod_padre,
       cod_mad_padre)
     select v_cdusuar,v_hora,v_nro_sec,v_cdmodul,v_cdmodal,v_cdofici,v_nrcuent,
            cod_moneda,v_fcfinal,v_fcdehoy,317,507,v_nrdocum,v_vlbloqu,'N',
            v_cdcaubl,v_cdofici,null,null, null, 'N',null,null,'N', 'N', v_cdmodul, v_cdmodal
       from ah_cta_certificados
      where nro_cuenta  = v_nrcuent;
     -- borro el registro del bloqueo
     delete from ge_bloqueos
      where rowid = v_rowid;
  END LOOP;
  IF bloqueocda%rowcount > 0 THEN
------------------------------------------------------------------------
-- procesa para aquellos que tengan saldo bloqueado = 0 (av_slblool)  --
-- y estado igual a "C" (av_esctaol)                                  --
------------------------------------------------------------------------
-----------------------------------------------
--  genera diario de movimientos             --
-----------------------------------------------
    v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
    insert into ge_movimientos
      (cod_usuario,hora,nro_secuencia,
       cod_modulo,cod_modalidad,cod_oficina,nro_cuenta,
       cod_moneda,fec_valor,fecha,cod_tra_padre,
       cod_transaccion,est_cuenta,estado,cod_ofi_origen,
       reversado,emi_aviso,protegido,cod_mod_padre,
       cod_mad_padre)
    select v_cdusuar, v_hora, v_nro_sec + rownum,
      cod_modulo,cod_modalidad,cod_oficina,nro_cuenta,
      cod_moneda,v_fcdehoy,v_fcdehoy,317, 425,'V','N',v_cdofici,
      'N', 'N', 'N', cod_modulo,cod_modalidad
    from ah_cta_certificados
    where sal_bloqueado = 0
      and sal_total > 0
      and estado = 'C';

   update ah_cta_certificados
       set estado = 'V',
           fec_cam_estado = v_fcdehoy
     where sal_bloqueado = 0
       and sal_total > 0
       and estado = 'C';

    v_nro_sec := v_nro_sec + bloqueocda%rowcount;
  END IF;
  CLOSE bloqueocda;
exception
  when others then
     raise_application_error(-20000,'ERROR: en CDA '||sqlerrm);
end;

PROCEDURE LP_LIB_BLO_CTA_CTE IS

  cursor BLOQUEOCC IS
    select gec.cod_modulo, gec.cod_modalidad, gec.cod_oficina,
           geb.nro_cuenta, geb.monto, geb.nro_documento, geb.cod_causa, geb.fec_fin
      from ge_bloqueos geb,
           ge_cuentas  gec
     where gec.cod_modulo   = 4
       and gec.cod_modalidad = 41
       and gec.nro_cuenta    = geb.nro_cuenta
       and geb.fec_fin is not null
       and geb.fec_fin < v_fcdehoy;

  v_cdmodul    ge_cuentas.cod_modulo%type;
  v_cdmodal    ge_cuentas.cod_modalidad%type;
  v_cdofici    ge_cuentas.cod_oficina%type;
  v_nrcuent    ge_bloqueos.nro_cuenta%type;
  v_vlbloqu    ge_bloqueos.monto%type;
  v_nrdocum    ge_bloqueos.nro_documento%type;
  v_cdcaubl    ge_bloqueos.cod_causa%type;
  v_fcfinal    ge_bloqueos.fec_fin%type;

BEGIN
  v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
  OPEN BLOQUEOCC;
  LOOP
     fetch BLOQUEOCC into V_CDMODUL, V_CDMODAL, V_CDOFICI,V_NRCUENT,
                          V_VLBLOQU, V_NRDOCUM, V_CDCAUBL,V_FCFINAL;
     exit when BLOQUEOCC%notfound;
    ---------------------------------------
    -- actualiza saldo bloqueado on line --
    ---------------------------------------
     update cc_cta_corrientes
        set sal_bloqueado = nvl(sal_bloqueado,0) - V_vlbloqu
      where nro_cuenta  = v_nrcuent;

    -----------------------------------------------
    --  genera diario de movimientos             --
    -----------------------------------------------
    v_nro_sec := v_nro_sec + 1;
    insert into ge_movimientos
      (cod_usuario,hora,nro_secuencia,
       cod_modulo,cod_modalidad,cod_oficina,nro_cuenta,
       cod_moneda,fec_valor,fecha,cod_tra_padre,
       cod_transaccion,nro_documento,monto,estado,
       cod_causa,cod_ofi_origen,concepto,
       cod_tasa,val_tasa,reversado,cod_usu_reversion,
       hor_reversion,emi_aviso,protegido,cod_mod_padre,
       cod_mad_padre)
    select v_cdusuar, v_hora, v_nro_sec,v_cdmodul,v_cdmodal,v_cdofici,v_nrcuent,
           cod_moneda,v_fcfinal,v_fcdehoy,317, 507,v_nrdocum,v_vlbloqu,'N',
           v_cdcaubl,v_cdofici,null,null, null, 'N',null,null,'N','N', v_cdmodul,v_cdmodal
      from cc_cta_corrientes
     where nro_cuenta  = v_nrcuent;
  END LOOP;
  IF bloqueocc%rowcount > 0 THEN
  ------------------------------------------------------------------------
  -- procesa para aquellos que tengan saldo bloqueado = 0 (mc_slblool)  --
  -- y estado igual a "S" (mc_esctaol)                                  --
  ------------------------------------------------------------------------
  --  genera diario de movimientos             --
  -----------------------------------------------
    v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
    insert into ge_movimientos
      (cod_usuario,hora,nro_secuencia,
       cod_modulo,cod_modalidad,cod_oficina,nro_cuenta,
       cod_moneda,fec_valor,fecha,cod_tra_padre,
       cod_transaccion,est_cuenta,estado,cod_ofi_origen,
       reversado,emi_aviso,protegido,cod_mod_padre,cod_mad_padre)
    select v_cdusuar, v_hora, v_nro_sec + rownum,cod_modulo,cod_modalidad,cod_oficina,nro_cuenta,
           cod_moneda,v_fcdehoy,v_fcdehoy,317,425,'N','N',v_cdofici,'N', 'N', 'N',
           cod_modulo, cod_modalidad
      from cc_cta_corrientes
     where sal_bloqueado = 0
       and estado = 'S';

    update cc_cta_corrientes
       set estado = 'N',
           fec_cam_estado = v_fcdehoy
     where sal_bloqueado = 0
       and estado = 'S';

     v_nro_sec := v_nro_sec + bloqueocc%rowcount;
  END IF;
  CLOSE bloqueocc;
exception
  when others then
     raise_application_error(-20000,'ERROR: en CTA.CTE '||sqlerrm);
end;
begin
   v_hora    := fug_ini_hora(sysdate,'HH24:MI:SS');
   v_cdusuar := substr(user,1,10);
   v_fcdehoy := pag_cal.fu_obt_fec_actual(3);
   v_nro_sec := 0;

   LP_LIB_BLO_AV;
   LP_LIB_BLO_CTA_CTE;
   LP_LIB_BLO_CDA;

   delete ge_bloqueos
   where fec_fin is not null and
         fec_fin < v_fcdehoy;
end;
/

