CREATE OR REPLACE TRIGGER IT.TA_CC_LIN_SOB_GARANTIAS
 AFTER DELETE OR INSERT OR UPDATE
 ON CC_LIN_SOB_GARANTIAS
 FOR EACH ROW

DECLARE
-- Para recuperar datos de la garantía y del sobregiro.
cursor garantia is
   select cc.cod_moneda cod_mon_sobregiro, cl.cod_oficina cod_ofi_sobregiro,
          ct.cod_modulo cod_mod_cuenta, ct.cod_modalidad cod_mad_cuenta, ct.cod_oficina cod_ofi_cuenta,
          ct.cod_moneda cod_mon_cuenta,ca.monto monto, ca.nro_cta_referencia nro_cta_referencia
     from pr_gar_cash ca,
          cc_lin_sobregiros cc,
          ge_cuentas ct,
          ge_clientes cl
    where ca.nro_garantia  = :new.nro_garantia
      and cc.nro_secuencia = :new.nro_secuencia
      and cc.cod_persona   = cl.cod_persona
      and cc.nro_sec_padre is null
      and ca.nro_cta_referencia = ct.nro_cuenta(+);
cursor garan is
   select cc.cod_moneda cod_mon_sobregiro, cl.cod_oficina cod_ofi_sobregiro,
          ct.cod_modulo cod_mod_cuenta, ct.cod_modalidad cod_mad_cuenta, ct.cod_oficina cod_ofi_cuenta,
          ct.cod_moneda cod_mon_cuenta,ca.monto monto, ca.nro_cta_referencia nro_cta_referencia
     from pr_gar_cash ca,
          cc_lin_sobregiros cc,
          ge_cuentas ct,
          ge_clientes cl
    where ca.nro_garantia  = :old.nro_garantia
      and cc.nro_secuencia = :old.nro_secuencia
      and cc.cod_persona   = cl.cod_persona
      and cc.nro_sec_padre is null
      and ca.nro_cta_referencia = ct.nro_cuenta(+);

  v_nro_linea      pr_lineas.nro_linea%type;
  v_cot_mon_ori    ge_cotizaciones.val_conversion%type;
  v_cot_mon_des    ge_cotizaciones.val_conversion%type;
  v_cod_mon_linea  pr_lineas.cod_moneda%type;
  v_cod_mon_gar    pr_garantias.cod_moneda%type;
  v_cod_mon_sob    cc_lin_sobregiros.cod_moneda%type;
  v_mto_a_aplicar  pr_lineas.mto_aplicado%type;
  v_mto_a_aplicado pr_lineas.mto_aplicado%type;
  v_mto_a_apli_gar pr_garantias.mto_aplicado%type;
  v_mto_bloqueo    ge_bloqueos.monto%type;
  v_mto_bloqueado  ge_bloqueos.monto%type;

  v_nvo_estado     ge_cuentas.estado%type;
  v_sal_disponible ge_cuentas.sal_contable%type;
  v_procesa        varchar2(01);

/* Verificar si es una cuenta de gestión financiera. */
FUNCTION LF_VER_CTA_GESTION
 (P_NRO_GARANTIA IN PR_GAR_CASH.NRO_GARANTIA%TYPE
 )
 RETURN NUMBER;
/* Insertar registro de bloqueos. */
PROCEDURE LP_INS_GE_BLOQUEOS
 (RP_GBLOQ IN GE_BLOQUEOS%ROWTYPE
 );
   v_diferencia         pr_garantias.mto_aplicado%type;
   v_cod_modalidad      ge_cuentas.cod_modalidad%type;
   v_fec_valor          ge_movimientos.fec_valor%type;
   v_hora               ge_movimientos.hora%type;
   r_gbloq              ge_bloqueos%rowtype;
   r_gmovi              ge_movimientos%rowtype;
   v_cantidad           number(05);
   v_cod_modulo         ge_cuentas.cod_modulo%type;
   v_cod_mad_sobregiro  ge_cuentas.cod_modalidad%type;
   v_cod_moneda         ge_cuentas.cod_moneda%type;
   v_cod_oficina        ge_cuentas.cod_oficina%type;
   v_cod_mod_cta        ge_cuentas.cod_modulo%type;
   v_cod_mad_cta        ge_cuentas.cod_modalidad%type;
   v_cod_mon_cta        ge_cuentas.cod_moneda%type;
   v_cod_ofi_cta        ge_cuentas.cod_oficina%type;
   v_nro_cta_referencia ge_cuentas.nro_cuenta%type;
   v_monto              ge_cuentas.sal_contable%type;
   v_nro_secuencia      ge_movimientos.nro_secuencia%type;

/*Obtener el monto bloqueoado de la cuenta*/
FUNCTION LF_OBT_MTO_BLOQUEO
 (p_nro_secuencia in ge_bloqueos.nro_documento%type,
  p_nro_cuenta in ge_bloqueos.nro_cuenta%type
 )
 return number;

/* Verificar si es una cuenta de gestión financiera. */
FUNCTION LF_VER_CTA_GESTION
 (P_NRO_GARANTIA IN PR_GAR_CASH.NRO_GARANTIA%TYPE
 )
 RETURN NUMBER
 IS
v_cod_modalidad ge_cuentas.cod_modalidad%type;
BEGIN
   select cod_modalidad
     into v_cod_modalidad
     from pr_cas_tipos ccc,
          pr_gar_cash ccg
    where ccg.nro_garantia = p_nro_garantia
      and ccg.cod_cas_tipo = ccc.cod_cas_tipo
      and rownum = 1;
   return v_cod_modalidad;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Tipo de Garantía '||p_nro_garantia||' no registrado');
END;

/* Insertar registro de bloqueos. */
PROCEDURE LP_INS_GE_BLOQUEOS
 (RP_GBLOQ IN GE_BLOQUEOS%ROWTYPE
 )
 IS
BEGIN
   insert into ge_bloqueos
      (nro_cuenta, fec_inicio, nro_documento,
       cod_causa, monto, hor_inicio,
       fec_fin, tipo, tip_bloqueo,observacion)
   values
      (rp_gbloq.nro_cuenta, rp_gbloq.fec_inicio, rp_gbloq.nro_documento,
       rp_gbloq.cod_causa, rp_gbloq.monto, rp_gbloq.hor_inicio,
       rp_gbloq.fec_fin, rp_gbloq.tipo, rp_gbloq.tip_bloqueo,rp_gbloq.observacion);
end;

/*Obtener el monto bloqueoado de la cuenta*/
FUNCTION LF_OBT_MTO_BLOQUEO
 (p_nro_secuencia  in ge_bloqueos.nro_documento%type,
  p_nro_cuenta in ge_bloqueos.nro_cuenta %type
 )
 return number
 IS
 v_monto ge_bloqueos.monto%type;
BEGIN
   select monto
     into v_monto
     from ge_bloqueos
   where nro_cuenta = p_nro_cuenta
	and nro_documento = p_nro_secuencia;

  return v_monto;
EXCEPTION
	when others then
		raise_application_error(-20000,'Obtener el monto bloqueado '||sqlerrm);
END;

BEGIN
  if inserting then
     v_nro_secuencia := substr(lpad(to_char(:new.nro_garantia),7,'0'),-3);
  else
     v_nro_secuencia := substr(lpad(to_char(:old.nro_garantia),7,'0'),-3);
  end if;
  If deleting OR updating  then

    --Actualizar el mto aplicado de tipos de garantia por limite
    begin
      select nro_linea,cod_moneda
        into v_nro_linea,v_cod_mon_sob
        from cc_lin_sobregiros
       where nro_secuencia = :old.nro_secuencia;
    exception
        when no_data_found then null;
    end;
    IF nvl(:new.mto_aplicado,0) <> nvl(:old.mto_aplicado,0) then
      begin
        If :old.cod_garantia > 2 and :old.nro_garantia is not null then
          -- Recuperar moneda de la garantia
           v_cod_mon_gar := pap_gar.fu_obt_mon_garantia(:old.nro_garantia);
           -- Convertir el monto a moneda de la garantia en la cotizacion actual
           pag_gen.pr_con_mon_a_moneda(v_cod_mon_sob, v_cod_mon_gar,
           nvl(:old.mto_aplicado,0), v_mto_a_apli_gar, v_cot_mon_ori, v_cot_mon_des);
           --- Actualizar monto aplicado de garantia
           pap_gar.pr_act_gar_aplicado(:old.nro_garantia, v_cod_mon_sob, (nvl(v_mto_a_apli_gar,0)*-1));
        End if;
/*
        --- Eliminar bloqueo de ahorros si la garantia es de cash
        if :old.cod_garantia in (5,12) then --Cash o Bloqueo de Saldo
           --- Verificar si corresponde a cuenta de ahorros
           v_cod_modalidad := lf_ver_cta_gestion(:old.nro_garantia);
           if v_cod_modalidad is not null and nvl(:old.mto_aplicado,0) <> 0 then
              v_fec_valor := pag_cal.fu_obt_fec_actual(4);
              v_hora      := to_char(sysdate,'hh24:mi:ss');
              --- Recuperar datos del cash y la ccopuesta
              for gar in garan loop
                --Obtener el monto bloqueado
                v_mto_bloqueado := LF_OBT_MTO_BLOQUEO(:old.nro_secuencia,gar.nro_cta_referencia);
                v_nro_secuencia :=  v_nro_secuencia + 1;
                -- Eliminar ge_bloqueos
                delete ge_bloqueos
                  where nro_cuenta    = gar.nro_cta_referencia
                    and nro_documento = :old.nro_secuencia;
                --- Actualizar saldo bloqueado
                If v_cod_modalidad in (31,41) then
                  --Verificar si se puede realizar el desbloqueo
                  pag_cta.pr_ver_operacion(gar.nro_cta_referencia,
                                            950,--cod_tra_padre
                                            3,
                                            v_cod_modalidad,
                                            'D',
                                            gar.cod_mon_cuenta,
                                            v_mto_bloqueado,
                                            gar.cod_ofi_sobregiro,
                                            -- out
                                            pag_cta.g_ctas.cod_modulo,
                                            pag_cta.g_ctas.cod_modalidad,
                                            v_nvo_estado,
                                            v_sal_disponible,
                                            v_procesa,
                                            604); --cod_transaccion
                  if pag_cta.g_cod_error <> 0 or v_procesa = 'N' then
                     raise_application_error(-20000,pag_cta.FU_OBT_MSJ_ERROR);
                  end if;

                  pag_cta.PR_ACT_SAL_CTA(gar.nro_cta_referencia, v_cod_modalidad, 'D',
                                       v_fec_valor, v_hora, null, null, v_mto_bloqueado, 'N');
                elsif v_cod_modalidad in (33,34) then--cda
                  --Verificar si se puede realizar el desbloqueo
                  pag_cta.pr_ver_operacion(gar.nro_cta_referencia,
                                            950,--cod_tra_padre
                                            3,
                                            v_cod_modalidad,
                                            'D',
                                            gar.cod_mon_cuenta,
                                            gar.monto,
                                            gar.cod_ofi_sobregiro,
                                            -- out
                                            pag_cta.g_ctas.cod_modulo,
                                            pag_cta.g_ctas.cod_modalidad,
                                            v_nvo_estado,
                                            v_sal_disponible,
                                            v_procesa,
                                            603); --cod_transaccion
                  if pag_cta.g_cod_error <> 0 or v_procesa = 'N' then
                     raise_application_error(-20000,pag_cta.FU_OBT_MSJ_ERROR);
                  end if;

                  pag_cta.PR_ACT_SAL_CTA(gar.nro_cta_referencia, v_cod_modalidad, 'D',
                                       v_fec_valor, v_hora, null, null, gar.monto, 'N');
                End if;
                --- Insertar movimiento de saldo bloqueado
                r_gmovi.cod_usuario     := user;
                r_gmovi.hora            := v_hora;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.cod_modulo      := gar.cod_mod_cuenta;
                r_gmovi.cod_modalidad   := gar.cod_mad_cuenta;
                r_gmovi.cod_oficina     := gar.cod_ofi_cuenta;
                r_gmovi.nro_cuenta      := gar.nro_cta_referencia;
                r_gmovi.cod_moneda      := gar.cod_mon_cuenta;
                r_gmovi.fec_valor       := v_fec_valor;
                r_gmovi.fecha           := v_fec_valor;
                r_gmovi.cod_tra_padre   := 950; --- Garantías de sobregiros
                r_gmovi.cod_transaccion := 507; --- Saldo bloqueado
                r_gmovi.estado          := 'N';
                r_gmovi.cod_ofi_origen  := gar.cod_ofi_sobregiro;
                r_gmovi.reversado       := 'N';
                r_gmovi.emi_aviso       := 'N';
                r_gmovi.protegido       := 'N';
                r_gmovi.cod_mod_padre   := 4;
                r_gmovi.cod_mad_padre   := 41;
                If v_cod_modalidad in (31,41) then
                  r_gmovi.monto           := nvl(v_mto_bloqueado,0);
                elsif v_cod_modalidad in (33,34) then
                  r_gmovi.monto           := nvl(gar.monto,0);
                End if;
                r_gmovi.nro_documento   := nvl(:old.nro_secuencia,0);
                r_gmovi.concepto        := 'Desbloqueo por garantia de sobreg.';
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                --- Verificar si posee aun bloqueo
                begin
                   select count(*) into v_cantidad
                     from ge_bloqueos
                    where nro_cuenta = v_nro_cta_referencia;
                exception
                  when no_data_found then
                    v_cantidad := 0;
                end;
                if v_cantidad = 0 then
                   If v_cod_modalidad in (33,34) then
                      --actualizar campo bloqueado a NO
                      pag_cta.PR_ACT_CTA_BLOQUEO(gar.nro_cta_referencia,'N');
                   else
                      --- Actualizar estado de la cuenta
                      pag_cta.PR_ACT_EST_CTA(gar.nro_cta_referencia, gar.cod_mad_cuenta, 'N', v_fec_valor);
                      --- Generar movimiento por cambio de estado
                      v_nro_secuencia :=  v_nro_secuencia + 1;
                      r_gmovi.cod_usuario     := user;
                      r_gmovi.hora            := v_hora;
                      r_gmovi.nro_secuencia   := v_nro_secuencia;
                      r_gmovi.cod_modulo      := gar.cod_mod_cuenta;
                      r_gmovi.cod_modalidad   := gar.cod_mad_cuenta;
                      r_gmovi.cod_oficina     := gar.cod_ofi_cuenta;
                      r_gmovi.nro_cuenta      := gar.nro_cta_referencia;
                      r_gmovi.cod_moneda      := gar.cod_mon_cuenta;
                      r_gmovi.fec_valor       := v_fec_valor;
                      r_gmovi.fecha           := v_fec_valor;
                      r_gmovi.cod_tra_padre   := 950; --- Garantías de sobegiros
                      r_gmovi.cod_transaccion := 415; --- Estado bloqueo de saldos
                      r_gmovi.est_cuenta      := 'N';
                      r_gmovi.estado          := 'N';
                      r_gmovi.cod_ofi_origen  := gar.cod_ofi_sobregiro;
                      r_gmovi.reversado       := 'N';
                      r_gmovi.emi_aviso       := 'N';
                      r_gmovi.protegido       := 'N';
                      r_gmovi.cod_mod_padre   := 4;
                      r_gmovi.cod_mad_padre   := 41;
                      r_gmovi.monto           := null;
                      r_gmovi.nro_documento   := :old.nro_secuencia;
                      r_gmovi.cod_causa       := fug_obt_pardinamico('COD_CAU_BLO_GARAN',
                                              4, 41, gar.cod_mon_sobregiro,
                                              gar.cod_ofi_sobregiro);
                      pag_gen.pr_ins_ge_movimiento(r_gmovi);
                   end if;
                end if;
              end loop;
            end if;
        end if;
		  */
      exception
        when others then
          If sqlcode <= -20000 then
            raise;
          else
            raise_application_error(-20001,'Al Eliminar garantia '||sqlerrm);
          End if;
      end;
    end if;
  end if;
  If inserting or (updating and nvl(:new.mto_aplicado,0) <> nvl(:old.mto_aplicado,0)) then
        --Obtener datos del sobregiro
        begin
            select nro_linea,cod_moneda
              into v_nro_linea,v_cod_mon_sob
              from cc_lin_sobregiros
             where nro_secuencia = :new.nro_secuencia;
        exception
            when no_data_found then
              v_nro_linea := null;
        End;
        begin
        --Actualizar el mto aplicado de garantias por limite
        If v_nro_linea is not null then
          -- Recuperar moneda de la linea y de la garantia
          v_cod_mon_linea  := pap_gar.fu_obt_mon_linea(v_nro_linea);
          If :new.cod_garantia > 2 then
            -- Convertir el monto a moneda de la linea en la cotizacion actual
            pag_gen.pr_con_mon_a_moneda(v_cod_mon_sob,v_cod_mon_linea,
                                       nvl(:new.mto_aplicado,0), v_mto_a_aplicar,
                                       v_cot_mon_ori, v_cot_mon_des);
            pag_gen.pr_con_mon_a_moneda(v_cod_mon_sob,v_cod_mon_linea,
                                       nvl(:old.mto_aplicado,0), v_mto_a_aplicado,
                                       v_cot_mon_ori, v_cot_mon_des);
          else
            v_mto_a_aplicar  := :new.mto_aplicado;
            v_mto_a_aplicado := :old.mto_aplicado;
          End if;
          pap_gar.pr_act_tip_limite(v_nro_linea,:new.cod_garantia,nvl(v_mto_a_aplicar,0)-nvl(v_mto_a_aplicado,0));
          --Actualizar el mto aplicado de garantias por Modalidad
          pap_gar.pr_act_mad_limite(v_nro_linea,:new.cod_garantia,nvl(v_mto_a_aplicar,0)-nvl(v_mto_a_aplicado,0),4,41);
        End if;
        --- Actualizar monto aplicado de garantia
        if :new.cod_garantia > 2 and :new.nro_garantia is not null then
           -- Recuperar moneda de la garantia
           v_cod_mon_gar := pap_gar.fu_obt_mon_garantia(:new.nro_garantia);
           -- Convertir el monto a moneda de la garantia en la cotizacion actual
           pag_gen.pr_con_mon_a_moneda(v_cod_mon_sob, v_cod_mon_gar,
           nvl(:new.mto_aplicado,0), v_mto_a_apli_gar, v_cot_mon_ori, v_cot_mon_des);
           pap_gar.pr_act_gar_aplicado(:new.nro_garantia, v_cod_mon_sob, nvl(v_mto_a_apli_gar,0));
        end if;
/*
        --- Bloquear ahorros si la garantia es de cash
        if :new.cod_garantia in (5,12) then --Cash o Bloqueo de Saldo
           --- Verificar si corresponde a cuenta de ahorros
           v_cod_modalidad := lf_ver_cta_gestion(:new.nro_garantia);
           if v_cod_modalidad is not null and nvl(:new.mto_aplicado,0) <> 0 then
              v_fec_valor := pag_cal.fu_obt_fec_actual(4);
              v_hora      := to_char(sysdate,'hh24:mi:ss');
              --- Recuperar datos del cash y la ccopuesta
              for gar in garantia loop
                --Convertir el monto a moneda de la cuenta en la cotizacion actual
                pag_gen.pr_con_mon_a_moneda(v_cod_mon_sob, gar.cod_mon_cuenta,
                  nvl(:new.mto_aplicado,0), v_mto_bloqueo, v_cot_mon_ori, v_cot_mon_des);

                v_nro_secuencia :=  v_nro_secuencia + 1;
                --- Insertar ge_bloqueos
                r_gbloq.nro_cuenta    := gar.nro_cta_referencia;
                r_gbloq.fec_inicio    := v_fec_valor;
                r_gbloq.nro_documento := :new.nro_secuencia;
                r_gbloq.cod_causa     := fug_obt_pardinamico('COD_CAU_BLO_GARAN',
                                         4, 41, gar.cod_mon_sobregiro,
                                         gar.cod_ofi_sobregiro);
                r_gbloq.hor_inicio    := v_hora;
                r_gbloq.fec_fin       := null;
                r_gbloq.tipo          := 'S'; --- Bloqueo de saldo
                r_gbloq.tip_bloqueo   := 'A';
                If v_cod_modalidad in (31,41) then
                  r_gbloq.monto         := v_mto_bloqueo;
                elsif v_cod_modalidad in (33,34) then
                  r_gbloq.monto         := gar.monto;
                End if;
                r_gbloq.observacion   := 'Bloqueo por utilización en el sobregiro N° '||:new.nro_secuencia;
                lp_ins_ge_bloqueos(r_gbloq);
                --- Actualizar saldo bloqueado
                If v_cod_modalidad in (31,41) then
                   --Verificar si se puede realizar el bloqueo
                   pag_cta.pr_ver_operacion(gar.nro_cta_referencia,
                                            950,--cod_tra_padre
                                            3,
                                            v_cod_modalidad,
                                            'C',
                                            gar.cod_mon_cuenta,
                                            v_mto_bloqueo,
                                            gar.cod_ofi_sobregiro,
                                            -- out
                                            pag_cta.g_ctas.cod_modulo,
                                            pag_cta.g_ctas.cod_modalidad,
                                            v_nvo_estado,
                                            v_sal_disponible,
                                            v_procesa,
                                            604); --cod_transaccion
                   if pag_cta.g_cod_error <> 0 or v_procesa = 'N' then
                     raise_application_error(-20000,pag_cta.FU_OBT_MSJ_ERROR);
                   end if;
                   pag_cta.PR_ACT_SAL_CTA(gar.nro_cta_referencia, v_cod_modalidad, 'C',
                                          v_fec_valor, v_hora, null, null, v_mto_bloqueo, 'N');
                elsif v_cod_modalidad in (33,34) then
                  --Verificar si se puede realizar el bloqueo
                  pag_cta.pr_ver_operacion(gar.nro_cta_referencia,
                                            950,--cod_tra_padre
                                            3,
                                            v_cod_modalidad,
                                            'C',
                                            gar.cod_mon_cuenta,
                                            gar.monto,
                                            gar.cod_ofi_sobregiro,
                                            -- out
                                            pag_cta.g_ctas.cod_modulo,
                                            pag_cta.g_ctas.cod_modalidad,
                                            v_nvo_estado,
                                            v_sal_disponible,
                                            v_procesa,
                                            603); --cod_transaccion
                  if pag_cta.g_cod_error <> 0 or v_procesa = 'N' then
                     raise_application_error(-20000,pag_cta.FU_OBT_MSJ_ERROR);
                  end if;
                  pag_cta.PR_ACT_SAL_CTA(gar.nro_cta_referencia, v_cod_modalidad, 'C',
                                          v_fec_valor, v_hora, null, null, gar.monto, 'N');
                End if;
                --- Insertar movimiento de saldo bloqueado
                r_gmovi.cod_usuario     := user;
                r_gmovi.hora            := v_hora;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.cod_modulo      := gar.cod_mod_cuenta;
                r_gmovi.cod_modalidad   := gar.cod_mad_cuenta;
                r_gmovi.cod_oficina     := gar.cod_ofi_cuenta;
                r_gmovi.nro_cuenta      := gar.nro_cta_referencia;
                r_gmovi.cod_moneda      := gar.cod_mon_cuenta;
                r_gmovi.fec_valor       := v_fec_valor;
                r_gmovi.fecha           := v_fec_valor;
                r_gmovi.cod_tra_padre   := 950; --- Garantías de sobregiros
                if gar.cod_mad_cuenta in (33,34,35) then
                   r_gmovi.cod_transaccion := 603; --- Saldo bloqueado
                else
                   r_gmovi.cod_transaccion := 604; --- Saldo bloqueado
                end if;
                If v_cod_modalidad in (31,41) then
                  r_gmovi.monto           := v_mto_bloqueo;
                elsif v_cod_modalidad in (33,34) then
                  r_gmovi.monto           := gar.monto;
                end if;
                r_gmovi.estado          := 'N';
                r_gmovi.cod_ofi_origen  := gar.cod_ofi_sobregiro;
                r_gmovi.reversado       := 'N';
                r_gmovi.emi_aviso       := 'N';
                r_gmovi.protegido       := 'N';
                r_gmovi.cod_mod_padre   := 4;
                r_gmovi.cod_mad_padre   := 41;
                r_gmovi.nro_documento   := :new.nro_secuencia;
                r_gmovi.cod_causa       := r_gbloq.cod_causa;
                r_gmovi.concepto        := 'Bloqueo por garantia de sobreg.';
                pag_gen.pr_ins_ge_movimiento(r_gmovi);
                --- Actualizar estado de la cuenta
                If v_cod_modalidad in (31,41) then
                   pag_cta.PR_ACT_EST_CTA(gar.nro_cta_referencia,  gar.cod_mad_cuenta, 'S', v_fec_valor);
                   --- Generar movimiento por cambio de estado
                   v_nro_secuencia :=  v_nro_secuencia + 1;
                   r_gmovi.cod_usuario     := user;
                   r_gmovi.hora            := v_hora;
                   r_gmovi.nro_secuencia   := v_nro_secuencia;
                   r_gmovi.cod_modulo      := gar.cod_mod_cuenta;
                   r_gmovi.cod_modalidad   := gar.cod_mad_cuenta;
                   r_gmovi.cod_oficina     := gar.cod_ofi_cuenta;
                   r_gmovi.nro_cuenta      := gar.nro_cta_referencia;
                   r_gmovi.cod_moneda      := gar.cod_mon_cuenta;
                   r_gmovi.fec_valor       := v_fec_valor;
                   r_gmovi.fecha           := v_fec_valor;
                   r_gmovi.cod_tra_padre   := 950; --- Garantías de sobregiros
                   r_gmovi.cod_transaccion := 409; --- Estado bloqueo de saldos
                   r_gmovi.est_cuenta      := 'S';
                   r_gmovi.estado          := 'N';
                   r_gmovi.cod_ofi_origen  := gar.cod_ofi_sobregiro;
                   r_gmovi.reversado       := 'N';
                   r_gmovi.emi_aviso       := 'N';
                   r_gmovi.protegido       := 'N';
                   r_gmovi.cod_mod_padre   := 4;
                   r_gmovi.cod_mad_padre   := 41;
                   r_gmovi.monto           := null;
                   r_gmovi.nro_documento   := :new.nro_secuencia;
                   r_gmovi.cod_causa       := r_gbloq.cod_causa;
                   pag_gen.pr_ins_ge_movimiento(r_gmovi);
                elsif v_cod_modalidad in (33,34) then
                    --actualizar campo bloqueado a NO
                    pag_cta.PR_ACT_CTA_BLOQUEO(gar.nro_cta_referencia,'S');
                End if;
              end loop;
           end if;
        end if;
		  */
      exception
        when others then
          If sqlcode <= -20000 then
            raise;
          else
            raise_application_error(-20001,'Al actulizar monto aplicado por tipo de garantia del limite... '||sqlerrm);
       End if;
      end;
  end if;
end;
/

