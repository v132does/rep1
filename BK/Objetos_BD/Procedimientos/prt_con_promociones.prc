CREATE OR REPLACE PROCEDURE IT.PRT_CON_PROMOCIONES(p_reproceso varchar2 default 'N') IS
  v_fcdehoy              date;
  v_hora                 ge_movimientos.hora%type;
  v_nro_secuencia        ge_movimientos.nro_secuencia%type;
  v_cod_mon_local        ba_monedas.cod_moneda%type;
  v_cod_ofi_origen       ba_usuarios.cod_oficina%type := FUG_OBT_OFI_USUARIO(USER);
  --
  v_cod_tra_padre        ge_transacciones.cod_transaccion%type := 237;
  v_rub_deb_entidad      cb_rubros.cod_rubro%type;
  v_rub_tra_comercio     cb_rubros.cod_rubro%type;
  v_rub_tra_tarjeta      cb_rubros.cod_rubro%type;
  v_cta_deb_comercio     ge_cuentas.nro_cuenta%type;
  --
  v_cor_convenio         ta_con_promociones.nro_convenio%type;
  v_cor_concepto         ta_con_promociones_mov.concepto%type;
  v_cor_concepto_mov     ta_con_promociones_mov.concepto%type;
  v_nro_convenio         ta_con_promociones_mov.nro_convenio%type;
  v_nro_convenio_1       ta_con_promociones_mov.nro_convenio%type;
  v_cod_rub_deb_entidad  ta_con_promociones.cod_rub_deb_entidad%type;
  v_nro_cta_deb_comercio ta_con_promociones.nro_cta_deb_comercio%type;
  v_nro_tarjeta          ta_con_promociones_mov.nro_tarjeta%type;
  v_cor_fecha            date;
  --
  v_por_otorgado         number;
  v_por_entidad          number;
  v_por_comercio         number;
  v_mto_entidad          number;
  v_mto_comercio         number;
  v_acu_mto_comercio     number;
  v_acu_mto_entidad      number;
  v_tot_mto_comercio     number;
  v_tot_mto_entidad      number;
  v_lin_sobregiro        number;
  v_disponible           number;
  v_existe               number;
  v_error                ta_con_promociones_mov.error%type;
  v_fila                 rowid;
  v_nro_tar_promocion    ta_con_promociones_mov.nro_tarjeta%type;
  v_lugar                VARCHAR2(500);
  v_tie_error             varchar2(1);

-- Variables de registro
  rg_movs                ge_movimientos%rowtype;
-- Cursor de los movimientos
  Cursor c_cursor is
  select p.*, rowid fila from ta_con_promociones_mov p
   where (
              (nvl(ind_reproceso,'N') = 'S'
           and nvl(p_reproceso,'N') = 'S'
           and error is not null)
             or
              (nvl(p_reproceso,'N') = 'N'
           and error is null
           and nvl(procesado,'N') = 'N'
           and cod_usuario = user
           and fecha = v_fcdehoy)
          )
   Order by nro_convenio,fec_proceso;

  Cursor c_cur_tar is
  select c.cod_modulo,c.cod_modalidad,c.cod_oficina,c.nro_cuenta, sum(p.mto_descuento) descuento
    from ta_cta_tarjetas c, ta_tarjetas t, ta_con_promociones_mov p
   where t.nro_tarjeta = p.nro_tarjeta
     and c.nro_cuenta = t.nro_cuenta
     and (
              (nvl(ind_reproceso,'N') = 'S'
           and nvl(p_reproceso,'N') = 'S'
           and nvl(procesado,'N') = 'N')
           --and error is not null
             or
              (nvl(p_reproceso,'N') = 'N'
           and error is null
           and nvl(procesado,'N') = 'N'
           and cod_usuario = user
           and fecha = v_fcdehoy)
         )
   Group by c.cod_modulo,c.cod_modalidad,c.cod_oficina,c.nro_cuenta
   Order by c.nro_cuenta;
-----
-- Procedimientos Internos
----
PROCEDURE LP_ACT_ERR_CON_PROMOCIONES
 (P_NRO_TARJETA IN TA_CON_PROMOCIONES_MOV.NRO_TARJETA%type,
  P_ERROR       IN TA_CON_PROMOCIONES_MOV.ERROR%type,
  P_MTO_COMPRA  IN TA_CON_PROMOCIONES_MOV.MTO_COMPRA%TYPE DEFAULT NULL,
  P_MTO_DESCUENTO  IN TA_CON_PROMOCIONES_MOV.MTO_DESCUENTO%TYPE DEFAULT NULL
 )
 IS
 PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
BEGIN
   v_error := P_ERROR;
   IF P_ERROR IS NOT NULL AND P_NRO_TARJETA IS NOT NULL THEN
     BEGIN
      UPDATE TA_CON_PROMOCIONES_MOV
         SET ERROR = v_error --P_ERROR
       WHERE NRO_TARJETA = P_NRO_TARJETA
         AND FECHA = v_fcdehoy
         AND (NRO_CONVENIO = v_nro_convenio or NRO_CONVENIO is null)
         AND MTO_COMPRA = nvl(p_mto_compra,mto_compra)
         AND MTO_DESCUENTO = nvl(p_mto_descuento,mto_descuento);
     EXCEPTION
       WHEN OTHERS THEN
           RAISE_APPLICATION_ERROR(-20009,SQLERRM);
     END;
   END IF;
   commit;
END;


PROCEDURE LP_VER_ERRORES( p_error out varchar2 ) IS
BEGIN
     p_error:='N';
   --Verificar errores
      --Traer datos del convenio
      Begin
        select nro_convenio, cod_rub_deb_entidad, nro_cta_deb_comercio
          into v_nro_convenio, v_cod_rub_deb_entidad, v_nro_cta_deb_comercio
          from ta_con_promociones
         where descripcion = v_cor_concepto;

      Exception
        when no_data_found then
           if nvl(p_reproceso,'N') = 'N' then
              lp_act_err_con_promociones( v_nro_tarjeta,'No existen datos para el Convenio : '||v_cor_concepto);
              p_error := 'S';
           else
              raise_application_error(-20000,'No existen datos para el Convenio : '||v_cor_concepto);
           end if;
        when others then
           if nvl(p_reproceso,'N') = 'N' then
              lp_act_err_con_promociones( v_nro_tarjeta,'Error al obtener datos de promociones: '||v_cor_concepto);
              p_error := 'S';
           else
              raise_application_error(-20000,'Error al obtener datos de promociones: '||v_cor_concepto||' Error : '||sqlerrm);
           end if;
      end;
      --Verificar si existe la tarjeta

      Select count(*) into v_existe
        from ta_tarjetas
       where nro_tarjeta = v_nro_Tarjeta;
      If v_existe = 0 then
         if nvl(p_reproceso,'N') = 'N' then
            lp_act_err_con_promociones( v_nro_tarjeta,'Tarjeta inexistente');
            p_error := 'S';
         else
            raise_application_error(-20000,'Tarjeta inexistente');
         end if;
      else
        --Verificar que el exista principal para la cuenta
        Select count(*) into v_existe
         from ge_cta_clientes g, ta_cta_tarjetas c, ta_tarjetas t
        where t.nro_tarjeta = v_nro_tarjeta
          and c.nro_cuenta = t.nro_cuenta
          and g.nro_cuenta = c.nro_cuenta
          and g.relacion = 'P';
        If v_existe = 0 then
           if nvl(p_reproceso,'N') = 'N' then
              lp_act_err_con_promociones( v_nro_tarjeta,'Cuenta sin Principal');
              p_error := 'S';
           else
              raise_application_error(-20000,'Cuenta sin Principal');
           end if;
        End if;
      End if;
END;

PROCEDURE PR_ACT_MOVIMIENTOS IS
  v_error varchar2(1);
BEGIN
  --VERIFICA ERRORES.
  LP_VER_ERRORES(v_error);
  /* 1er Paso : Debitar a una cuenta transitoria la porción que le corresponde al comercio
    acreditar al rubro de gasto definido para la promoción  */
  --Debito a la cuenta transitoria
  If nvl(v_acu_mto_comercio,0) <> 0 then
    -- Requerimiento:CNFPRDTC-4.
    IF v_nro_secuencia >= 998 THEN
       v_nro_secuencia := -999;
       v_hora          := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
       rg_movs.hora    := v_hora;
    End IF;
    --
    v_nro_secuencia         := v_nro_secuencia + 1;
    rg_movs.nro_secuencia   := v_nro_secuencia;
    rg_movs.cod_mod_padre   := 4;
    rg_movs.cod_mad_padre   := 41;
    rg_movs.cod_tra_padre   := v_cod_tra_padre;
    rg_movs.cod_transaccion := null;
    rg_movs.monto           := v_acu_mto_comercio;
    rg_movs.cod_moneda      := v_cod_mon_local;
    rg_movs.cod_modulo      := null;
    rg_movs.cod_modalidad   := null;
    rg_movs.nro_cuenta      := null;
    rg_movs.cod_oficina     := v_cod_ofi_origen;
    rg_movs.nro_documento   := v_nro_convenio_1;
    rg_movs.nro_documento2  := null;
    rg_movs.cod_tasa        := null;
    rg_movs.val_tasa        := null;
    rg_movs.cotizacion      := null;
    rg_movs.emi_aviso       := 'N';
    rg_movs.cod_ofi_origen  := v_cod_ofi_origen;
    rg_movs.concepto        := substr('Fec.: '||to_char(v_cor_fecha,'dd/mm/yyyy')||' Promocion: '||v_cor_concepto_mov,1,100);
    rg_movs.estado          := 'N';
    rg_movs.est_cuenta      := 'N';
    rg_movs.reversado       := 'N';
    rg_movs.emi_aviso       := 'N';
    rg_movs.nro_caja        := null;
    rg_movs.cod_rubro       := v_rub_tra_comercio;
    rg_movs.tip_mov_rubro   := 'D'; -- Débito
    --
    PAG_GEN.PR_INS_GE_MOVIMIENTO(rg_movs,'N'); -- inserta datos en ge_movimientos

    -- Requerimiento:CNFPRDTC-4.
    -- Genero el movimiento que afecta resultado a nivel de cuenta de cliente.
    /*--Debito a la cuenta transitoria la porción del comercio
    v_nro_secuencia := v_nro_secuencia + 1;
    rg_movs.nro_secuencia   := v_nro_secuencia;
    rg_movs.cod_mod_padre   := 4;
    rg_movs.cod_mad_padre   := 41;
    rg_movs.cod_tra_padre   := v_cod_tra_padre;
    rg_movs.cod_transaccion := null;
    rg_movs.monto           := v_acu_mto_comercio;
    rg_movs.cod_moneda      := v_cod_mon_local;
    rg_movs.cod_modulo      := null;
    rg_movs.cod_modalidad   := null;
    rg_movs.nro_cuenta      := null;
    rg_movs.cod_oficina     := v_cod_ofi_origen;
    rg_movs.nro_documento   := v_nro_convenio_1;
    rg_movs.nro_documento2  := null;
    rg_movs.cod_tasa        := null;
    rg_movs.val_tasa        := null;
    rg_movs.cotizacion      := null;
    rg_movs.emi_aviso       := 'N';
    rg_movs.cod_ofi_origen  := v_cod_ofi_origen;
    rg_movs.concepto        := substr('Fec.: '||to_char(v_cor_fecha,'dd/mm/yyyy')||' Promocion: '||v_cor_concepto_mov,1,100);
    rg_movs.estado          := 'N';
    rg_movs.est_cuenta      := 'N';
    rg_movs.reversado       := 'N';
    rg_movs.emi_aviso       := 'N';
    rg_movs.nro_caja        := null;
    rg_movs.cod_rubro       := v_rub_deb_entidad;
    rg_movs.tip_mov_rubro   := 'C'; -- Crédito
    --
    PAG_GEN.PR_INS_GE_MOVIMIENTO(rg_movs,'N'); -- inserta datos en ge_movimientos*/

  /* 2do Paso : Luego grabar un movimiento con la transaccion 509 que
    debitara al comercio la porción que le corresponde y
    acreditara a la cuenta transitoria, si la cuenta del comercio tiene saldo
    suficiente o sino va a movimientos pendientes
  */
  ---Veficiar que tenga cuenta de debito
    If v_cta_deb_comercio is null then
       if nvl(p_reproceso,'N') = 'N' then
          lp_act_err_con_promociones( v_cor_convenio,'Para la promoción: ' || v_cor_concepto ||'  No se ha cargado la cta. de debito del comercio.');
       else
          raise_application_error(-20000,'Para la promoción: ' || v_cor_concepto ||'  No se ha cargado la cta. de debito del comercio.');
       end if;
    End if;
  --- Recuperar datos de la cuenta del comercio
    pag_cta.PR_OBT_CUENTA(v_cta_deb_comercio);
    if pag_cta.g_cod_error <> 0 then
       if nvl(p_reproceso,'N') = 'N' then
          lp_act_err_con_promociones( v_cor_convenio,'Recup. datos de la cuenta ' || v_cta_deb_comercio || ' - ' ||pag_cta.g_msj_error);
       else
          raise_application_error(-20000,'Recup. datos de la cuenta ' || v_cta_deb_comercio || ' - ' ||pag_cta.g_msj_error);
       end if;
    --  raise_application_error(-20000,'Recup. datos de la cuenta ' || v_cta_deb_comercio || ' - ' ||pag_cta.g_msj_error);
    end if;
    -- Calcular el disponible,  Se tiene en cuenta la linea de sobregiro
    v_lin_sobregiro := 0;
    if pag_cta.g_ctas.cod_modalidad = 41 then  --Si es cta.cte se sobregira siempre
       pag_cta.g_sobregira := 'S';
    end if;
    --Disponible = disponible normal + saldo en cta.combinada
    v_disponible := nvl(pag_cta.g_ctas.sal_disponible,0)+nvl(pag_cta.g_ctas.sal_dis_combinada,0);
    --
    If v_disponible >= v_acu_mto_comercio or pag_cta.g_ctas.cod_modalidad = 41 then
      --Debito a la cuenta transitoria
      PAG_CTA.PR_ACT_OPERACION
                 (v_cta_deb_comercio  -- P_NRO_CUENTA
                 ,v_hora        -- P_HORA
                 ,'D'           -- P_TIP_MOVIMIENTO
                 ,pag_cta.G_CTAS.cod_moneda  -- P_COD_MONEDA
                 ,v_acu_mto_comercio     -- P_MONTO
                 ,v_cod_tra_padre   -- P_COD_TRA_PADRE
                 ,509   -- P_COD_TRANSACCION
                 ,null  --P_NRO_DOCUMENTO
                 ,null          --P_COTIZACION
                 ,v_cod_ofi_origen  -- P_COD_OFI_ORIGEN
                 ,4   -- P_COD_MOD_PADRE
                 ,41  -- P_COD_MAD_PADRE
                 ,null          --P_COD_TASA
                 ,null          --P_VAL_TASA
                 ,substr('Fec.: '||to_char(v_cor_fecha,'dd/mm/yyyy')||' Promocion: '||v_cor_concepto_mov,1,100) -- P_CONCEPTO
                 ,'N'           -- p_EMI_AVISO
                 ,v_nro_secuencia -- P_NRO_SECUENCIA IN OUT
                 ,v_fcdehoy       -- P_FEC_VALOR
                 ,null          -- P_COD_BANCO
                 ,null          -- P_COD_CAUSA
                 ,null);        -- P_MTO_EQU_LOCAL
    else
      --Si no hay fondos sufiecientes va a movimientos pendientes
      Insert into Ge_Mov_Pendientes
      (nro_cuenta,Fecha,Cod_modulo,Cod_modalidad,Cod_transaccion,
       Cod_mod_padre,Cod_mad_padre,Cod_tra_padre,Monto,
       Hora,Cod_usuario,
       Cod_moneda,Cod_oficina,Estado,Cod_ofi_origen,
       Concepto,
       Cod_tasa,Val_tasa,Nro_documento,saldo)
      Values
       (v_cta_deb_comercio,v_fcdehoy,pag_cta.g_Ctas.cod_modulo,pag_cta.g_Ctas.cod_modalidad,509,
        4,41,v_cod_tra_padre,nvl(v_acu_mto_comercio,0),
        v_hora,user,
        pag_cta.g_ctas.cod_moneda,pag_cta.G_CTAS.cod_oficina,'I',v_cod_ofi_origen,
        substr('Fec.: '||to_char(v_cor_fecha,'dd/mm/yyyy')||' Promocion: '||v_cor_concepto_mov,1,35),
        null,null,null,nvl(v_acu_mto_comercio,0));
      End if;
   End if;
END;
/* Procedimiento que contabiliza x Promoción  */
PROCEDURE PR_ACT_MOV_CONVENIO IS
BEGIN
 /* Debitar el total del la promoción al rubro de gasto definido en la promoción
    Acreditar a la cuenta 'Deudores x tarjetas ' */

   -- Requerimiento:CNFPRDTC-4.
   -- Genero el movimiento que afecta resultado a nivel de cuenta de cliente.
 /*--Debito al Rubro definido en la promoción
   v_nro_secuencia := v_nro_secuencia + 1;
   rg_movs.nro_secuencia   := v_nro_secuencia;
   rg_movs.cod_mod_padre   := 4;
   rg_movs.cod_mad_padre   := 41;
   rg_movs.cod_tra_padre   := v_cod_tra_padre;
   rg_movs.cod_modulo      := null;
   rg_movs.cod_modalidad   := null;
   rg_movs.cod_transaccion := null;
   rg_movs.monto           := v_tot_mto_entidad+v_tot_mto_comercio;
   rg_movs.cod_moneda      := v_cod_mon_local;
   rg_movs.nro_cuenta      := null;
   rg_movs.cod_oficina     := v_cod_ofi_origen;
   rg_movs.nro_documento   := v_nro_convenio_1;
   rg_movs.nro_documento2  := null;
   rg_movs.cod_tasa        := null;
   rg_movs.val_tasa        := null;
   rg_movs.cotizacion      := null;
   rg_movs.emi_aviso       := 'N';
   rg_movs.cod_ofi_origen  := v_cod_ofi_origen;
   rg_movs.concepto        := substr('Convenio de Promociones : '||v_cor_concepto_mov,1,100);
   rg_movs.estado          := 'N';
   rg_movs.est_cuenta      := 'N';
   rg_movs.reversado       := 'N';
   rg_movs.emi_aviso       := 'N';
   rg_movs.nro_caja        := null;
   rg_movs.cod_rubro       := v_rub_deb_entidad;
   rg_movs.tip_mov_rubro   := 'D'; -- Débito
   --
   PAG_GEN.PR_INS_GE_MOVIMIENTO(rg_movs,'N'); -- inserta datos en ge_movimientos*/

   --Credito al Rubro 'Deudores x Tarjetas'
   -- Requerimiento:CNFPRDTC-4.
   IF v_nro_secuencia >= 998 THEN
      v_nro_secuencia := -999;
      v_hora          := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
      rg_movs.hora    := v_hora;
   End IF;
   --
   v_nro_secuencia         := v_nro_secuencia + 1;
   rg_movs.nro_secuencia   := v_nro_secuencia;
   rg_movs.cod_mod_padre   := 4;
   rg_movs.cod_mad_padre   := 41;
   rg_movs.cod_tra_padre   := v_cod_tra_padre;
   rg_movs.cod_modulo      := null;
   rg_movs.cod_modalidad   := null;
   rg_movs.cod_transaccion := null;
   rg_movs.cod_moneda      := v_cod_mon_local;
   rg_movs.cod_oficina     := v_cod_ofi_origen;
   rg_movs.nro_cuenta      := null;
   rg_movs.monto           := v_tot_mto_entidad+v_tot_mto_comercio;
   rg_movs.nro_documento   := v_nro_convenio_1;
   rg_movs.nro_documento2  := null;
   rg_movs.cod_tasa        := null;
   rg_movs.val_tasa        := null;
   rg_movs.cotizacion      := null;
   rg_movs.emi_aviso       := 'N';
   rg_movs.cod_ofi_origen  := v_cod_ofi_origen;
   rg_movs.concepto        := substr('Convenio de Promociones : '||v_cor_concepto_mov,1,100);
   rg_movs.estado          := 'N';
   rg_movs.est_cuenta      := 'N';
   rg_movs.reversado       := 'N';
   rg_movs.emi_aviso       := 'N';
   rg_movs.nro_caja        := null;
   rg_movs.cod_rubro       := v_rub_tra_tarjeta;
   rg_movs.tip_mov_rubro   := 'C'; -- Credito
   --
   PAG_GEN.PR_INS_GE_MOVIMIENTO(rg_movs,'N'); -- inserta datos en ge_movimientos

END;

-- Requerimiento:CNFPRDTC-4.
-- Genero el movimiento que afecta resultado a nivel de cuenta de cliente por comercio.
PROCEDURE PR_ACT_MOV_DETALLADO(p_monto in ta_con_promociones_mov.mto_compra%type,
                               p_nro_tarjeta in ta_con_promociones_mov.nro_tarjeta%type)
IS
v_nro_cuenta      ta_cta_tarjetas.nro_cuenta%type := NULL;
v_cod_modulo      ta_cta_tarjetas.cod_modulo%type := NULL;
v_cod_modalidad   ta_cta_tarjetas.cod_modalidad%type := NULL;
v_cod_transaccion ge_movimientos.cod_transaccion%type := 9237;
BEGIN
  -- Obtengo el Nro. de Cuenta de la Tarjeta.
  BEGIN
     SELECT g.nro_cuenta, g.cod_modulo, g.cod_modalidad
       INTO v_nro_cuenta, v_cod_modulo, v_cod_modalidad
       FROM ge_cta_clientes g, ta_cta_tarjetas c, ta_tarjetas t
      WHERE t.nro_tarjeta = p_nro_tarjeta
        AND c.nro_cuenta = t.nro_cuenta
        AND g.nro_cuenta = c.nro_cuenta
        AND g.relacion = 'P';
  EXCEPTION
     WHEN OTHERS THEN
        v_nro_cuenta    := NULL;
        v_cod_modulo    := NULL;
        v_cod_modalidad := NULL;
  END;
  --
  IF nvl(p_monto,0) <> 0 THEN
     --Debito a la cuenta transitoria la porción del comercio
     -- Requerimiento:CNFPRDTC-4.
     IF v_nro_secuencia >= 998 THEN
        v_nro_secuencia := -999;
        v_hora          := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
        rg_movs.hora    := v_hora;
     End IF;
     --
     v_nro_secuencia         := v_nro_secuencia + 1;
     rg_movs.nro_secuencia   := v_nro_secuencia;
     rg_movs.cod_mod_padre   := 4;
     rg_movs.cod_mad_padre   := 41;
     rg_movs.cod_tra_padre   := v_cod_tra_padre;
     rg_movs.cod_transaccion := v_cod_transaccion;
     rg_movs.monto           := nvl(p_monto,0);
     rg_movs.cod_moneda      := v_cod_mon_local;
     rg_movs.cod_modulo      := v_cod_modulo;
     rg_movs.cod_modalidad   := v_cod_modalidad;
     rg_movs.nro_cuenta      := null;
     rg_movs.cod_oficina     := v_cod_ofi_origen;
     rg_movs.nro_documento   := v_nro_convenio_1;
     rg_movs.nro_documento2  := null;
     rg_movs.cod_tasa        := null;
     rg_movs.val_tasa        := null;
     rg_movs.cotizacion      := null;
     rg_movs.emi_aviso       := 'N';
     rg_movs.cod_ofi_origen  := v_cod_ofi_origen;
     rg_movs.concepto        := substr('Fec.: '||to_char(v_cor_fecha,'dd/mm/yyyy')||' Promocion: '||v_cor_concepto_mov,1,100);
     rg_movs.estado          := 'N';
     rg_movs.est_cuenta      := 'N';
     rg_movs.reversado       := 'N';
     rg_movs.emi_aviso       := 'N';
     rg_movs.nro_caja        := null;
     rg_movs.cod_rubro       := v_rub_deb_entidad;
     rg_movs.tip_mov_rubro   := 'C'; -- Crédito
     rg_movs.referencia      := v_nro_cuenta;
     --
     PAG_GEN.PR_INS_GE_MOVIMIENTO(rg_movs,'N'); -- inserta datos en ge_movimientos*/
     --
     rg_movs.referencia      := NULL;
     rg_movs.cod_transaccion := NULL;
     rg_movs.cod_modulo      := NULL;
     rg_movs.cod_modalidad   := NULL;
  END IF;
END;

-- Requerimiento:CNFPRDTC-4.
-- Genero el movimiento que afecta resultado a nivel de cuenta de cliente por convenio.
PROCEDURE PR_ACT_COV_DETALLADO(p_monto in ta_con_promociones_mov.mto_compra%type,
                               p_nro_tarjeta in ta_con_promociones_mov.nro_tarjeta%type)
IS
v_nro_cuenta ta_cta_tarjetas.nro_cuenta%type := NULL;
v_cod_modulo      ta_cta_tarjetas.cod_modulo%type := NULL;
v_cod_modalidad   ta_cta_tarjetas.cod_modalidad%type := NULL;
v_cod_transaccion ge_movimientos.cod_transaccion%type := 9237;
BEGIN
   -- Obtengo el Nro. de Cuenta de la Tarjeta.
   BEGIN
      SELECT g.nro_cuenta, g.cod_modulo, g.cod_modalidad
        INTO v_nro_cuenta, v_cod_modulo, v_cod_modalidad
        FROM ge_cta_clientes g, ta_cta_tarjetas c, ta_tarjetas t
       WHERE t.nro_tarjeta = p_nro_tarjeta
         AND c.nro_cuenta = t.nro_cuenta
         AND g.nro_cuenta = c.nro_cuenta
         AND g.relacion = 'P';
   EXCEPTION
      WHEN OTHERS THEN
         v_nro_cuenta    := NULL;
         v_cod_modulo    := NULL;
         v_cod_modalidad := NULL;
   END;
   --Debito al Rubro definido en la promoción
   -- Requerimiento:CNFPRDTC-4.
   IF nvl(p_monto,0) <> 0 THEN
      IF v_nro_secuencia >= 998 THEN
         v_nro_secuencia := -999;
         v_hora          := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
         rg_movs.hora    := v_hora;
      End IF;
      --
      v_nro_secuencia         := v_nro_secuencia + 1;
      rg_movs.nro_secuencia   := v_nro_secuencia;
      rg_movs.cod_mod_padre   := 4;
      rg_movs.cod_mad_padre   := 41;
      rg_movs.cod_tra_padre   := v_cod_tra_padre;
      rg_movs.cod_modulo      := v_cod_modulo;
      rg_movs.cod_modalidad   := v_cod_modalidad;
      rg_movs.cod_transaccion := v_cod_transaccion;
      rg_movs.monto           := NVL(p_monto,0);
      rg_movs.cod_moneda      := v_cod_mon_local;
      rg_movs.nro_cuenta      := null;
      rg_movs.cod_oficina     := v_cod_ofi_origen;
      rg_movs.nro_documento   := v_nro_convenio_1;
      rg_movs.nro_documento2  := null;
      rg_movs.cod_tasa        := null;
      rg_movs.val_tasa        := null;
      rg_movs.cotizacion      := null;
      rg_movs.emi_aviso       := 'N';
      rg_movs.cod_ofi_origen  := v_cod_ofi_origen;
      rg_movs.concepto        := substr('Convenio de Promociones : '||v_cor_concepto_mov,1,100);
      rg_movs.estado          := 'N';
      rg_movs.est_cuenta      := 'N';
      rg_movs.reversado       := 'N';
      rg_movs.emi_aviso       := 'N';
      rg_movs.nro_caja        := null;
      rg_movs.cod_rubro       := v_rub_deb_entidad;
      rg_movs.tip_mov_rubro   := 'D'; -- Débito
      rg_movs.referencia      := v_nro_cuenta;
      --
      PAG_GEN.PR_INS_GE_MOVIMIENTO(rg_movs,'N'); -- inserta datos en ge_movimientos
      --
      rg_movs.referencia      := NULL;
      rg_movs.cod_transaccion := NULL;
      rg_movs.cod_modulo      := NULL;
      rg_movs.cod_modalidad   := NULL;
   END IF;
END;

--*
--*   PROCEDIMIENTO PRINCIPAL
--*
BEGIN
 v_fcdehoy       := pag_cal.fu_obt_fec_actual(4);    -- fecha de hoy
 v_hora          := to_char( sysdate, 'HH24:MI:SS' );
 v_hora          := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
 v_nro_secuencia := -999;
 pag_cta.g_sobregira := 'N';

 v_cod_mon_local := pag_gen.fu_obt_mon_local;
 --Obtener el rubro de Deudores x Tarjetas
 --v_rub_deu_tarjetas := fug_obt_pardinamico('COD_RUB_DEU_TARJETAS');
 --Obtener el rubro Trasitorio para debito al comercio, buscar en la definicion del asiento
 --de la transaccion 509 con el tipo de movimiento Credito
 v_lugar := 'Error_1';
 Begin
   select distinct a.cod_rubro
     into v_rub_tra_comercio
     from ge_tip_asientos a, ge_transacciones t
    where t.cod_modulo = 4 and t.cod_modalidad = 41
      and t.cod_transaccion = 509
      and (a.cod_tip_asiento = t.cod_tip_asiento
       or  a.cod_tip_asiento = t.cod_tip_asiento2)
      and a.tip_movimiento = 'C';
 Exception
   when others then
      if nvl(p_reproceso,'N') = 'N' then
         lp_act_err_con_promociones( v_cor_convenio,'Recup. datos de la cuenta ' || v_cta_deb_comercio || ' - ' ||pag_cta.g_msj_error);
      else
         raise_application_error(-20000,'No se ha podido obtener el Rubro Transitorio asociado a la Transacción 509.'||' - Error : '||sqlerrm);
      end if;
 End;
 --Obtener el rubro Trasitorio de Débito por tarjeta, buscar en la definicion del asiento
 --de la transaccion 510 con el tipo de movimiento Débito
  v_lugar := 'Error_2';
 Begin
   select distinct a.cod_rubro
     into v_rub_tra_tarjeta
     from ge_tip_asientos a, ge_transacciones t
    where t.cod_modulo = 5 and t.cod_modalidad = 51
      and t.cod_transaccion = 510
      and (a.cod_tip_asiento = t.cod_tip_asiento
       or  a.cod_tip_asiento = t.cod_tip_asiento2)
      and a.tip_movimiento = 'D';
 Exception
   when others then
      if nvl(p_reproceso,'N') = 'N' then
         lp_act_err_con_promociones( v_cor_convenio,'No se ha podido obtener el Rubro Transitorio asociado a la Transacción 510.'||' - Error : '||sqlerrm);
      else
         raise_application_error(-20000,'No se ha podido obtener el Rubro Transitorio asociado a la Transacción 510.'||' - Error : '||sqlerrm);
      end if;
 End;

  v_lugar := 'Error_3';
 --Asignar valores generales para registro de movimientos
 rg_movs.COD_USUARIO     := user;
 rg_movs.hora            := v_hora;
 rg_movs.fecha           := v_fcdehoy;
 rg_movs.fec_valor       := v_fcdehoy;
 --
  v_lugar := 'Error_4';
 For reg in c_cursor loop
     v_error := null;

     if nvl(p_reproceso,'N') = 'S' then
        select nro_convenio
          into reg.nro_convenio
          from ta_con_promociones
         where descripcion = reg.concepto;
     end if;
     --Se debe agrupar x comercio y tipo de promocion
     If  v_cor_convenio is null then
        --Guardar la variables de corte de control e iniciar acumulados
        v_cor_convenio := reg.nro_convenio;
        v_rub_deb_entidad  := reg.cod_rub_deb_entidad;
        v_nro_convenio_1 := reg.nro_convenio;
        v_cta_deb_comercio := reg.nro_cta_deb_comercio;
        v_acu_mto_entidad     := 0;
        v_acu_mto_comercio    := 0;
        v_tot_mto_entidad     := 0;
        v_tot_mto_comercio    := 0;
     End if;
        v_cor_concepto := reg.concepto;
        v_cor_fecha    := reg.fec_proceso;
        --v_rub_deb_entidad  := reg.cod_rub_deb_entidad;
        v_nro_tarjeta  := reg.nro_tarjeta;

      --VERIFICA ERRORES.
      v_tie_error := 'N';
      LP_VER_ERRORES(v_tie_error);

      if v_tie_error = 'N' then


           v_por_entidad  := 0;
           v_por_comercio := 0;
           --Calcular el porcentaje otorgado al cliente
           v_por_otorgado := round((reg.mto_descuento*100)/reg.mto_compra);
           --Con el porcentaje otorgado verificar si es promocion especial y obtener la participación
           /*Begin
            Select por_entidad, por_comercio
              into v_por_entidad, v_por_comercio
              from ta_con_promociones_det
             where nro_convenio = reg.nro_convenio
               and por_descuento = v_por_otorgado
               and reg.fec_operacion between fec_inicio and fec_fin;
           Exception
             when no_data_found then
              v_por_entidad := 0;
              v_por_comercio := 0;
             when others then
                if nvl(p_reproceso,'N') = 'N' then
                   lp_act_err_con_promociones( reg.nro_tarjeta,'Error al obtener datos de participacion en el Convenio : '||reg.nro_convenio||' Error : '||sqlerrm);
                   v_tie_error := 'S';
                else
                   raise_application_error(-20000,'Error al obtener datos de participacion en el Convenio : '||reg.nro_convenio||' Error : '||sqlerrm);
                end if;
           End;*/
           --Si no es promocion especial entonces traer la participación normal
           If v_por_entidad = 0 and v_por_comercio = 0 then
             Begin
              Select por_entidad, por_comercio
                into v_por_entidad, v_por_comercio
                from ta_con_promociones
               where nro_convenio = reg.nro_convenio
                 /*and por_descuento = v_por_otorgado*/;
             Exception
              when no_data_found then
                 if nvl(p_reproceso,'N') = 'N' then
                    lp_act_err_con_promociones( reg.nro_tarjeta /*v_cor_convenio*/,'No se ha encontrado datos para el Convenio : '||reg.nro_convenio||' y el Descuento otorgado : '||to_char(v_por_otorgado,'999D99'),reg.mto_compra,reg.mto_descuento);
                    v_tie_error := 'S';
                 else
                    raise_application_error(-20000,'No se ha encontrado datos para el Convenio : '||reg.nro_convenio||' y el Descuento otorgado : '||to_char(v_por_otorgado,'999D99'));
                 end if;
              when others then
                 if nvl(p_reproceso,'N') = 'N' then
                    lp_act_err_con_promociones( reg.nro_tarjeta /*v_cor_convenio*/,'Error al obtener datos de participacion en el Convenio : '||reg.nro_convenio||' Error : '||sqlerrm);
                 else
                    raise_application_error(-20000,'Error al obtener datos de participacion en el Convenio : '||reg.nro_convenio||' Error : '||sqlerrm);
                 end if;
             End;
           End if;
---
           if nvl(v_tie_error,'N') = 'N' then
               If reg.nro_convenio <> v_cor_convenio
               or reg.fec_proceso  <> v_cor_fecha   then --Corte de control x Convenio ,fecha de proceso
                  -- Requerimiento:CNFPRDTC-4.
                  -- Genero el movimiento que afecta resultado a nivel de cuenta de cliente.
                  -- if v_cta_deb_comercio is not null then
                     PR_ACT_MOVIMIENTOS;
                  -- end if;
                  IF reg.nro_convenio <> v_cor_convenio then --Si el corte fue de convenio, contabilizar la promocion
                    PR_ACT_MOV_CONVENIO;
                    v_rub_deb_entidad  := reg.cod_rub_deb_entidad;
                    v_tot_mto_comercio := 0;
                    v_tot_mto_entidad  := 0;
                  END IF;
                 /*
                 -- Guardar las variables del corte de control e reiniciar los acumulados
                 */
                 v_cor_convenio := reg.nro_convenio;
                 v_nro_convenio_1 := reg.nro_convenio;
                 v_cor_concepto_mov := reg.concepto;
                 v_cor_Fecha    := reg.fec_proceso;
                 v_cta_deb_comercio := reg.nro_cta_deb_comercio;
                 v_acu_mto_comercio   := 0;
                 v_acu_mto_entidad    := 0;
               End if;

---
               --Calcular los montos que corresponden a la Entidad y al Comercio
               v_mto_entidad  := round((reg.mto_descuento*v_por_entidad)/100);
               v_mto_comercio := reg.mto_descuento- v_mto_entidad;
               --Acumular para el corte
               v_acu_mto_entidad := nvl(v_acu_mto_entidad,0)+nvl(v_mto_entidad,0);
               v_acu_mto_comercio:= nvl(v_acu_mto_comercio,0)+nvl(v_mto_comercio,0);
               --
               v_tot_mto_entidad := nvl(v_tot_mto_entidad,0)+nvl(v_mto_entidad,0);
               v_tot_mto_comercio:= nvl(v_tot_mto_comercio,0)+nvl(v_mto_comercio,0);
               -- Requerimiento:CNFPRDTC-4.
               -- Genero el movimiento que afecta resultado a nivel de cuenta de cliente.
               PR_ACT_MOV_DETALLADO(NVL(v_mto_comercio,0), reg.nro_tarjeta);
               PR_ACT_COV_DETALLADO(NVL(v_mto_entidad,0)+NVL(v_mto_comercio,0), reg.nro_tarjeta);
               --
           end if;
           v_fila              := reg.fila;
           v_nro_tar_promocion := reg.nro_tarjeta;
           --
           IF v_error IS NULL AND v_nro_tar_promocion IS NOT NULL AND nvl(p_reproceso,'N') = 'S' THEN
              UPDATE TA_CON_PROMOCIONES_MOV
                 SET ERROR = null
               WHERE NRO_TARJETA = v_nro_tar_promocion
                 AND rowid = v_fila;
           END IF;
      end if;
 End loop;

 v_lugar := 'Error_5';
 --Procesar Corte de control por fin de archivo
 If v_cor_convenio is not null then
    v_tie_error := 'N';
    LP_VER_ERRORES(v_tie_error);
    if v_tie_error = 'N' then
        -- Requerimiento:CNFPRDTC-4.
        -- Genero el movimiento que afecta resultado a nivel de cuenta de cliente.
        -- if v_cta_deb_comercio is not null then
           PR_ACT_MOVIMIENTOS;
        -- end if;
        --PR_ACT_MOVIMIENTOS;
        PR_ACT_MOV_CONVENIO;
        IF v_error IS NULL AND v_nro_tar_promocion IS NOT NULL AND nvl(p_reproceso,'N') = 'S' THEN
           UPDATE TA_CON_PROMOCIONES_MOV
              SET ERROR = null
            WHERE NRO_TARJETA = v_nro_tar_promocion
              AND rowid = v_fila;
        END IF;
    end if;
 End if;
 v_lugar := 'Error_6';
 --Procesar Asiento x Tarjeta, se graba la transaccion 510 que Debito Cta.Transitoria de Tarjeta
 --y Acredita Cuenta de Tarjeta
 For t in c_cur_tar loop
   v_tie_error :='N';
   LP_VER_ERRORES(v_tie_error);
   if v_tie_error = 'N' then
       if v_nro_secuencia >= 998 then
          v_nro_secuencia := -999;
          v_hora          := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
          rg_movs.hora    := v_hora;
       End IF;
       v_nro_secuencia := v_nro_secuencia + 1;
       v_lugar := 'Error_7 '||t.nro_cuenta||' - '||v_nro_secuencia;
       rg_movs.nro_secuencia   := v_nro_secuencia;
       rg_movs.cod_mod_padre   := 4;
       rg_movs.cod_mad_padre   := 41;
       rg_movs.cod_tra_padre   := v_cod_tra_padre;
       rg_movs.cod_modulo      := t.cod_modulo;
       rg_movs.cod_modalidad   := t.cod_modalidad;
       rg_movs.cod_transaccion := 510;
       rg_movs.monto           := t.descuento;
       rg_movs.cod_moneda      := v_cod_mon_local;
       rg_movs.nro_cuenta      := t.nro_cuenta;
       rg_movs.cod_oficina     := t.cod_oficina;
       rg_movs.nro_documento   := null;
       rg_movs.nro_documento2  := null;
       rg_movs.cod_tasa        := null;
       rg_movs.val_tasa        := null;
       rg_movs.cotizacion      := null;
       rg_movs.emi_aviso       := 'N';
       rg_movs.cod_ofi_origen  := v_cod_ofi_origen;
       rg_movs.concepto        := substr('Convenio de Promociones '||'Cta. '||t.nro_cuenta,1,100);
       rg_movs.estado          := 'N';
       rg_movs.est_cuenta      := 'N';
       rg_movs.reversado       := 'N';
       rg_movs.emi_aviso       := 'N';
       rg_movs.nro_caja        := null;
       rg_movs.cod_rubro       := null;
       rg_movs.tip_mov_rubro   := null;
       --
       PAG_GEN.PR_INS_GE_MOVIMIENTO(rg_movs,'N'); -- inserta datos en ge_movimientos
    end if;
  End loop;
   v_lugar := 'Error_7';
   --Actualizar como procesados los movimientos
   Update ta_con_promociones_mov
      set procesado = 'S',
          ind_reproceso = 'N'
    where (
              (nvl(ind_reproceso,'N') = 'S'
           and nvl(p_reproceso,'N') = 'S'
           and nvl(procesado,'N') = 'N')
           --and error is not null)
             or
              (nvl(p_reproceso,'N') = 'N'
           and error is null
           and nvl(procesado,'N') = 'N'
           and cod_usuario = user
           and fecha = v_fcdehoy)
          );
--
   pag_cta.g_sobregira := 'N';
EXCEPTION
   WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20000,'ERROR '||V_LUGAR|| SQLERRM );
END;
/

