CREATE OR REPLACE PROCEDURE IT.PRC_PRO_TRA_CTA_EMB
 IS
  -- Variables.
  v_fcdehoy         date;
  v_cantmov         number(6);
  v_nrsecue         ge_movimientos.nro_secuencia%type;
  v_hora            ge_movimientos.hora%type :=  fug_obt_hor_disponible(v_fcdehoy,to_char(sysdate,'HH24:MI:SS'),user,'N');--fug_ini_hora(SYSDATE, 'HH24:MI:SS');
  v_fcanter         ge_calendarios.fec_anterior%TYPE;
  v_cod_cau_embargo ge_par_causales.val_parametro%TYPE;

  -- Cursores.
  cursor c_cta_embargadas is
  select gec.cod_sec_contable,gec.cod_tip_deudor,gec.residente,
         cte.cod_moneda, gem.cod_moneda mon_embargo, gem.cod_ofi_origen cod_oficina,
         nvl(ged.mto_embargado,0) mto_embargado,
         ged.mto_mon_cuenta, mto_emb_ge_blo, ge.cod_modulo, ge.cod_modalidad, ge.nro_cuenta
    from ge_cuentas ge,
         ge_cta_clientes gcc,
         cc_cta_corrientes cte,
         ge_clientes gec,
         ge_embargos gem,
         ge_embargos_det ged,
         (select x.nro_cuenta xx_nro_cuenta,
                 sum(nvl(x.monto,0)) mto_emb_ge_blo, x.nro_documento
            from ge_bloqueos x
             where x.cod_causa = v_cod_cau_embargo --EMBARGOS--
            group by x.nro_cuenta, x.nro_documento
         )
   where ge.nro_cuenta = gcc.nro_cuenta
     and gcc.cod_persona = gec.cod_persona
     and ged.nro_cuenta = ge.nro_cuenta
     and gem.cod_embargo = ged.cod_embargo
     and xx_nro_cuenta = ge.nro_cuenta
     and nro_documento = ged.cod_embargo
     and gcc.nro_cuenta = cte.nro_cuenta
     and gem.estado = 'A'
     and cte.estado <> 'C'
     and gcc.relacion = 'P'
  union all
  select gec.cod_sec_contable,gec.cod_tip_deudor,gec.residente,
         cte.cod_moneda, gem.cod_moneda mon_embargo, gem.cod_ofi_origen cod_oficina,
         nvl(ged.mto_embargado,0) mto_embargado,
         ged.mto_mon_cuenta, mto_emb_ge_blo, ge.cod_modulo, ge.cod_modalidad, ge.nro_cuenta
    from ge_cuentas ge,
         ge_cta_clientes gcc,
         ah_cta_vistas cte,
         ge_clientes gec,
         ge_embargos gem,
         ge_embargos_det ged,
         (select x.nro_cuenta xx_nro_cuenta,
                 sum(nvl(x.monto,0)) mto_emb_ge_blo, x.nro_documento
            from ge_bloqueos x
             where x.cod_causa = v_cod_cau_embargo --EMBARGOS--
            group by x.nro_cuenta, x.nro_documento
         )
   where ge.nro_cuenta = gcc.nro_cuenta
     and gcc.cod_persona = gec.cod_persona
     and ged.nro_cuenta = ge.nro_cuenta
     and gem.cod_embargo = ged.cod_embargo
     and xx_nro_cuenta = ge.nro_cuenta
     and nro_documento = ged.cod_embargo
     and gcc.nro_cuenta = cte.nro_cuenta
     and gem.estado = 'A'
     and cte.estado <> 'C'
     and gcc.relacion = 'P';

-- Procedimientos Internos.
PROCEDURE LP_GEN_MOV_TRA (p_cdmodul in number, p_cdmodal in number, p_cdtrans in number,
                          p_cdofici in number, p_cdmoned in char, p_importe in number, p_nro_cuenta in char) is
  -- Variables.
  r_gmovi     GE_MOVIMIENTOS%ROWTYPE;

BEGIN
   -- Genera los movimientos.
   v_nrsecue :=  v_nrsecue + 1;
   if v_nrsecue > 900 then
      v_nrsecue := -999;
      --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
      v_hora:= fug_obt_hor_disponible(v_fcdehoy,v_hora,user,'N');
   end if;
   r_gmovi.cod_modulo      := p_cdmodul;
   r_gmovi.cod_modalidad   := p_cdmodal;
   r_gmovi.cod_oficina     := p_cdofici;
   r_gmovi.nro_cuenta      := p_nro_cuenta;
   r_gmovi.cod_rubro       := NULL;
   r_gmovi.tip_mov_rubro   := NULL;
   r_gmovi.cod_moneda      := p_cdmoned;
   r_gmovi.cod_usuario     := upper(user);
   r_gmovi.hora            := v_hora;
   r_gmovi.fecha           := v_fcdehoy;
   r_gmovi.nro_secuencia   := v_nrsecue;
   --
   r_gmovi.fec_valor       := v_fcdehoy;
   r_gmovi.cod_tra_padre   := 855;
   r_gmovi.cod_mod_padre   := p_cdmodul;
   r_gmovi.cod_mad_padre   := p_cdmodal;
   r_gmovi.cod_transaccion := p_cdtrans;
   r_gmovi.monto           := p_importe;
   r_gmovi.nro_documento   := null;
   r_gmovi.nro_documento2  := null;
   r_gmovi.nro_documento3  := null;
   r_gmovi.cod_tasa        := null;
   r_gmovi.val_tasa        := null;
   r_gmovi.cotizacion      := null;
   r_gmovi.cod_ofi_origen  := p_cdofici;
   r_gmovi.emi_aviso       := 'N';
   r_gmovi.concepto        := 'Transf.de Ctas.Embargadas';
   r_gmovi.estado          := 'N';
   r_gmovi.reversado       := 'N';
   --
   pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
   --
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,'Genera movimientos, nro_cuenta: ' || p_nro_cuenta || SQLERRM);
END;

PROCEDURE LP_CAN_EMB_ANTERIOR IS
-- Variables.
cursor c_cta_emb_anterior is
    SELECT cod_modulo, cod_modalidad, cod_oficina, cod_moneda, cod_tra_padre, cod_transaccion,
           monto, estado, reversado, cod_mod_padre, cod_mad_padre,  nro_cuenta, cod_ofi_origen
     FROM cc_movimientos_his
    WHERE fecha = v_fcanter
      AND cod_modulo = 4
      AND cod_modalidad = 41
      AND cod_transaccion = 855
      AND monto > 0
      AND concepto='Transf.de Ctas.Embargadas'
  UNION ALL
     SELECT cod_modulo, cod_modalidad, cod_oficina, cod_moneda, cod_tra_padre, cod_transaccion,
            monto, estado, reversado, cod_mod_padre, cod_mad_padre, nro_cuenta, cod_ofi_origen
       FROM ah_movimientos_his
      WHERE fecha = v_fcanter
        AND cod_modulo = 3
        AND cod_modalidad = 31
        AND cod_transaccion = 855
        AND monto > 0
        AND concepto='Transf.de Ctas.Embargadas' ;

v_hora ge_movimientos.hora%TYPE:= fug_obt_hor_disponible(v_fcdehoy,to_char(sysdate,'HH24:MI:SS'),user,'N');--fug_ini_hora(sysdate,'HH24:MI:SS');

BEGIN
      For x IN c_cta_emb_anterior loop
        v_nrsecue :=  v_nrsecue + 1;
        if v_nrsecue > 900 then
           v_nrsecue := -999;
           --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
           v_hora:= fug_obt_hor_disponible(v_fcdehoy,v_hora,user,'N');
        end if;
         --- Se inserta en ge_movimientos los mov. inversos a los embargos del dia ant.
         INSERT INTO ge_movimientos
            (cod_modulo, cod_modalidad, cod_oficina, cod_moneda, cod_tra_padre, cod_transaccion,
             fecha, fec_valor, monto, estado, concepto, reversado, cod_mod_padre, cod_mad_padre,
             cod_usuario, hora, nro_secuencia, nro_cuenta, cod_ofi_origen)
          VALUES
            (x.cod_modulo, x.cod_modalidad, x.cod_oficina, x.cod_moneda, x.cod_tra_padre, x.cod_transaccion,
             v_fcdehoy, v_fcdehoy, x.monto * -1, x.estado, 'Reversión Embargos', x.reversado, x.cod_mod_padre, x.cod_mad_padre,
             user, v_hora, v_nrsecue, x.nro_cuenta, x.cod_ofi_origen) ;
      end loop ;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR. Embargo_Cancelacion ' || SQLERRM);
   END;

BEGIN
    -- Seteo de variables.
    v_fcdehoy         := pag_cal.fu_obt_fec_actual(4);
    v_fcanter         := pag_cal.fu_obt_fec_anterior(4);
    v_nrsecue         := -999;
    v_hora            := fug_obt_hor_disponible(v_fcdehoy,to_char(sysdate,'HH24:MI:SS'),user,'N');--fug_ini_hora(v_fcdehoy,'HH24:MI:SS');
    v_cod_cau_embargo := fug_obt_pardinamico('COD_CAU_BLO_EMBAR');
    --Verificar que no existan movimientos de transf. de embargos ya procesados del día.
    select count(*)
      into v_cantmov
      from ge_movimientos
    where cod_transaccion = 855;
    if nvl(v_cantmov,0) > 0 and nvl(pae_cnf.g_programa, 'X') <> 'GPPROFIN' then
       raise_application_error(-20001,'Movimientos de transf. de embargos ya generados anteriormente');
    end if;
    --Generar movimientos de reversión para los traslados de embargos del día anterior.
    LP_CAN_EMB_ANTERIOR;
    for ce in c_cta_embargadas loop
       if ce.mto_embargado <> 0 then
          LP_GEN_MOV_TRA(ce.cod_modulo, ce.cod_modalidad, 855, ce.cod_oficina, ce.cod_moneda,
                         nvl(ce.mto_emb_ge_blo,0), ce.nro_cuenta);
       end if;
    end loop;
exception
  when others then
    raise_application_error(-20000,'Error en transferencia_contable '  ||' - '  ||sqlerrm);
end;
/

