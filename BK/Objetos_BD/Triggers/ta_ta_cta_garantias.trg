CREATE OR REPLACE TRIGGER IT.TA_TA_CTA_GARANTIAS
 AFTER DELETE OR INSERT OR UPDATE
 ON TA_CTA_GARANTIAS
 FOR EACH ROW

DECLARE
-- Para recuperar datos de la garantía y la propuesta.
cursor garantia is
   select pr.cod_modulo cod_mod_prestamo, pr.cod_modalidad cod_mad_prestamo,
          pr.cod_moneda cod_mon_prestamo, pr.cod_oficina cod_ofi_prestamo,
          ct.cod_modulo cod_mod_cuenta, ct.cod_modalidad cod_mad_cuenta, ct.cod_oficina cod_ofi_cuenta,
          ct.cod_moneda cod_mon_cuenta,ca.monto monto, ca.nro_cta_referencia nro_cta_referencia
     from pr_gar_cash ca,
          ta_cta_tarjetas pr,
          ge_cuentas ct
    where ca.nro_garantia  = :new.nro_garantia
      and pr.nro_cuenta = :new.nro_cuenta
      and ca.nro_cta_referencia = ct.nro_cuenta(+);

cursor garan is
   select pr.cod_modulo cod_mod_prestamo, pr.cod_modalidad cod_mad_prestamo,
          pr.cod_moneda cod_mon_prestamo, pr.cod_oficina cod_ofi_prestamo,
          ct.cod_modulo cod_mod_cuenta, ct.cod_modalidad cod_mad_cuenta, ct.cod_oficina cod_ofi_cuenta,
          ct.cod_moneda cod_mon_cuenta,ca.monto monto, ca.nro_cta_referencia nro_cta_referencia
     from pr_gar_cash ca,
          ta_cta_tarjetas pr,
          ge_cuentas ct
    where ca.nro_garantia  = :old.nro_garantia
      and pr.nro_cuenta = :old.nro_cuenta
      and ca.nro_cta_referencia = ct.nro_cuenta(+);

  v_nro_linea      pr_lineas.nro_linea%type;
  v_cod_mon_linea  pr_lineas.cod_moneda%type;
  v_cod_mod_pres   ta_cta_tarjetas.cod_modalidad%type;
  v_cod_mon_pres   ta_cta_tarjetas.cod_moneda%type;
  v_cod_mon_gar    pr_garantias.cod_moneda%type;
  v_mto_a_aplicar  pr_lineas.mto_aplicado%type;
  v_mto_aplicado pr_lineas.mto_aplicado%type;
  v_mto_a_apli_gar pr_garantias.mto_aplicado%type;
  v_cot_mon_ori    ge_cotizaciones.val_conversion%type;
  v_cot_mon_des    ge_cotizaciones.val_conversion%type;
  v_mto_bloqueo    ge_bloqueos.monto%type;
  v_mto_bloqueado  ge_bloqueos.monto%type;

  v_nvo_estado     ge_cuentas.estado%type;
  v_sal_disponible ge_cuentas.sal_contable%type;
  v_procesa        varchar2(01);
  v_nro_cuenta     ta_cta_tarjetas.nro_cuenta%type;
  v_aplicado       pr_garantias.mto_aplicado%type;
  v_tipo           pr_garantias.tipo%type;
  v_estado         pr_garantias.estado%type;

/* Verificar si la garantía ya se cargó a la solicitud. */
FUNCTION LF_VER_GAR_SOLICITUD
 (P_NRO_GARANTIA IN PR_GAR_CASH.NRO_GARANTIA%TYPE,
  P_COD_GARANTIA IN PR_GARANTIAS.COD_GARANTIA%TYPE,
 P_NRO_SOLICITUD IN OUT ta_solicitudes.NRO_SOLICITUD%TYPE
 )
RETURN BOOLEAN;

/*actualizar bloqueos*/
PROCEDURE LP_ACT_BLOQUEO
 (p_cta_referencia ge_bloqueos.nro_cuenta%type,
 p_nro_solicitud ge_bloqueos.nro_documento%type,
 p_nro_cuenta ge_bloqueos.nro_documento%type
 );


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
   v_cod_modulo         ta_cta_tarjetas.cod_modulo%type;
   v_cod_mad_prestamo   ta_cta_tarjetas.cod_modalidad%type;
   v_cod_moneda         ta_cta_tarjetas.cod_moneda%type;
   v_cod_oficina        ta_cta_tarjetas.cod_oficina%type;
   v_cod_mod_cta        ge_cuentas.cod_modulo%type;
   v_cod_mad_cta        ge_cuentas.cod_modalidad%type;
   v_cod_mon_cta        ge_cuentas.cod_moneda%type;
   v_cod_ofi_cta        ge_cuentas.cod_oficina%type;
   v_nro_cta_referencia ge_cuentas.nro_cuenta%type;
   v_monto              ge_cuentas.sal_contable%type;
   v_nro_secuencia      ge_movimientos.nro_secuencia%type :=0;
   v_nro_solicitud      ta_solicitudes.nro_solicitud%type;
   v_gar_saldo      pr_garantias.mto_aplicado%type;

/*Obtener el monto bloqueoado de la cuenta*/
FUNCTION LF_OBT_MTO_BLOQUEO
 (p_nro_documento in ge_bloqueos.nro_documento%type,
  p_nro_cuenta in ge_bloqueos.nro_cuenta%type
 )
 return number;

/* Verificar si la garantía ya se cargó a la solicitud. */
FUNCTION LF_VER_GAR_SOLICITUD
 (P_NRO_GARANTIA IN PR_GAR_CASH.NRO_GARANTIA%TYPE,
  P_COD_GARANTIA IN PR_GARANTIAS.COD_GARANTIA%TYPE,
 P_NRO_SOLICITUD IN OUT ta_solicitudes.NRO_SOLICITUD%TYPE
 )
RETURN BOOLEAN IS
BEGIN
   SELECT NRO_SOLICITUD
   INTO P_NRO_SOLICITUD
   FROM ta_sol_garantias
   WHERE NRO_GARANTIA = P_NRO_GARANTIA
   AND COD_GARANTIA =P_COD_GARANTIA;
   RETURN TRUE;
EXCEPTION
  WHEN TOO_MANY_ROWS THEN
      RETURN TRUE;
   WHEN NO_DATA_FOUND THEN
        RETURN FALSE;
   WHEN OTHERS THEN
        RETURN FALSE;
END;

/*actualizar el bloqueo*/
PROCEDURE LP_ACT_BLOQUEO
 (p_cta_referencia ge_bloqueos.nro_cuenta%type,
 p_nro_solicitud ge_bloqueos.nro_documento%type,
 p_nro_cuenta ge_bloqueos.nro_documento%type
 )
 IS
BEGIN
   update ge_bloqueos
      set nro_documento = p_nro_cuenta
   where nro_cuenta = p_cta_referencia
	and nro_documento = p_nro_solicitud;
EXCEPTION
	when others then
		raise_application_error(-20000,'Act.Bloqueo '||sqlerrm);
END;


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
     from pr_cas_tipos prc,
          pr_gar_cash prg
    where prg.nro_garantia = p_nro_garantia
      and prg.cod_cas_tipo = prc.cod_cas_tipo
      and rownum = 1;
   return v_cod_modalidad;
exception
   when no_data_found then
      return 0;
   when others then
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
       fec_fin, tipo, observacion, tip_bloqueo)
   values
      (rp_gbloq.nro_cuenta, rp_gbloq.fec_inicio, rp_gbloq.nro_documento,
       rp_gbloq.cod_causa, rp_gbloq.monto, rp_gbloq.hor_inicio,
       rp_gbloq.fec_fin, rp_gbloq.tipo, rp_gbloq.observacion, 'A');
END;
/*Obtener el monto bloqueado de la cuenta*/
FUNCTION LF_OBT_MTO_BLOQUEO
 (p_nro_documento in ge_bloqueos.nro_documento%type,
  p_nro_cuenta    in ge_bloqueos.nro_cuenta %type
 )
 return number
 IS
 v_monto ge_bloqueos.monto%type;
BEGIN
   select monto
     into v_monto
     from ge_bloqueos
    where nro_cuenta = p_nro_cuenta
  	  and nro_documento = p_nro_documento;
  return v_monto;
EXCEPTION
  when no_data_found then
     return 0;
	when others then
		raise_application_error(-20000,'Obtener el monto bloqueado '||sqlerrm);
END;
/*Verificar si el bloqueo tipo A ya existe,
significa q el cash está atado a otro préstamo*/
FUNCTION LF_VER_BLOQUEO
 (p_nro_cuenta     in ge_bloqueos.nro_cuenta %type
 )
 return BOOLEAN
 IS
 v_existe number;
BEGIN
   select count(*)
     into v_existe
     from ge_bloqueos
    where nro_cuenta = p_nro_cuenta
	   and tip_bloqueo ='A';
   if v_existe >0 then
     return true;
   else
     return false;
   end if;
EXCEPTION
	when others then
		raise_application_error(-20000,'Recup. bloqueo '||sqlerrm);
END;

/*principal*/
BEGIN
   if inserting or updating then
      v_nro_cuenta := :new.nro_cuenta;
   else
      v_nro_cuenta := :old.nro_cuenta;
   end if;

   begin
      select nro_linea,cod_moneda,cod_modalidad
        into v_nro_linea,v_cod_mon_pres,v_cod_mod_pres
        from ta_cta_tarjetas
       where nro_cuenta = v_nro_cuenta;
      exception
       when no_data_found then
         v_nro_linea := null;
   End;

   --- POR ELIMINACION O MODIFICACION DEL MONTO APLICADO
   If deleting OR updating  then
     IF nvl(:new.mto_apl_computable,0) <> nvl(:old.mto_apl_computable,0) then
       begin
          If :old.cod_garantia > 2 and :old.nro_garantia is not null then
            -- Actualizar monto aplicado de garantia
            pap_gar.pr_act_gar_aplicado(:old.nro_garantia, v_cod_mon_pres, (nvl(:old.mto_apl_computable,0)*-1));
            pap_gar.pr_act_gar_aplicado(:new.nro_garantia, v_cod_mon_pres, nvl(:new.mto_apl_computable,0));
          End if;
        exception
          when others then
            If sqlcode <= -20000 then
              raise;
            else
              raise_application_error(-20001,'Al Actualizar Garantía'||sqlerrm);
            End if;
        end;
      end if;
   End if;

  --- POR INSERT
  if inserting then
    --actualizar la garantia con el nuevo monto aplicado computable
    --sólo si no existe ta_solicitudes, o sino ya se actualizó por el insert de la misma
    If :new.cod_garantia > 2 then
       if not lf_ver_gar_solicitud(:new.nro_garantia,:new.cod_garantia, v_nro_solicitud) then
         if nvl(:new.mto_apl_computable,0) <> 0 then
            pap_gar.pr_act_gar_aplicado(:new.nro_garantia, v_cod_mon_pres, nvl(:new.mto_apl_computable,0));
         end if;
       end if;
    end if;
  elsif updating and nvl(:new.mto_aplicado,0) <> nvl(:old.mto_aplicado,0) then
    begin
      --Actualizar el mto aplicado de garantias por limite
      If v_nro_linea is not null then
        If :new.cod_garantia > 2 then
          -- Recuperar moneda de la linea y de la garantia
          v_cod_mon_linea  := pap_gar.fu_obt_mon_linea(v_nro_linea);
          v_cod_mon_gar    := pap_gar.fu_obt_mon_garantia(:new.nro_garantia);
          -- Convertir el monto a moneda de la linea en la cotizacion actual
          pag_gen.pr_con_mon_a_moneda(v_cod_mon_pres,v_cod_mon_linea,
                                     nvl(:new.mto_aplicado,0), v_mto_a_aplicar,
                                     v_cot_mon_ori, v_cot_mon_des);
          pag_gen.pr_con_mon_a_moneda(v_cod_mon_pres,v_cod_mon_linea,
                                     nvl(:old.mto_aplicado,0), v_mto_aplicado,
                                     v_cot_mon_ori, v_cot_mon_des);
        else
          pag_gen.pr_con_mon_a_moneda(v_cod_mon_pres,v_cod_mon_linea,
                                     nvl(:new.mto_aplicado,0), v_mto_a_aplicar,
                                     v_cot_mon_ori, v_cot_mon_des);
          pag_gen.pr_con_mon_a_moneda(v_cod_mon_pres,v_cod_mon_linea,
                                     nvl(:old.mto_aplicado,0), v_mto_aplicado,
                                     v_cot_mon_ori, v_cot_mon_des);
        End if;
        pap_gar.pr_act_tip_limite(v_nro_linea,:new.cod_garantia,nvl(v_mto_a_aplicar,0)-nvl(v_mto_aplicado,0));
        --Actualizar el mto aplicado de garantias por Modalidad
        pap_gar.pr_act_mad_limite(v_nro_linea,:new.cod_garantia,nvl(v_mto_a_aplicar,0)-nvl(v_mto_aplicado,0),6,v_cod_mod_pres);
      End if;
    exception
      when others then
        If sqlcode <= -20000 then
          raise;
        else
          raise_application_error(-20000,'Al actualizar garantias '||sqlerrm);
        End if;
    end;
  end if;
END;
/

