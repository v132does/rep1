CREATE OR REPLACE PROCEDURE IT.PRC_DEB_CHQ_MON_INFERIOR
 IS
  --v_modulo       ge_cuentas.cod_modulo%type;
  --v_modalidad    ge_cuentas.cod_modalidad%type;
  --v_oficina      ge_cuentas.cod_oficina%type;
  v_cod_ofi_origen ge_cuentas.cod_oficina%type;
  --v_moneda       ge_cuentas.cod_moneda%type;
  v_transaccion  ge_movimientos.cod_transaccion%type;
  v_hora         ge_movimientos.hora%type;
  v_nro_Secuencia ge_movimientos.nro_secuencia%type; 
  v_fcdehoy       date;
  --v_encontro     varchar2(1);
  v_cod_error    number;
  v_hubo_error   varchar2(1);
  v_lugar        varchar2(1000);
  v_tas_personalizada varchar2(1);
  v_can_exento   number;
  v_cantidad     number;
  v_sal_disponible  cc_cta_corrientes.sal_total%type;
  v_estado          cc_cta_corrientes.estado%type;
  v_iva_incluido    varchar2(1);
  v_cod_tas_cargo   ge_tasas.cod_Tasa%type;
  v_val_tas_cargo   ge_tas_fechas.val_tasa%type;
  v_mto_Cargo       ge_movimientos.monto%type;  
  v_tra_iva         ge_movimientos.cod_transaccion%type; 
  v_cod_tas_iva     ge_tasas.cod_tasa%type;
  v_val_tas_iva     ge_tas_fechas.val_tasa%type;
  v_mto_iva         number;
  v_mto_mov         number;
  ---
  v_fre_proceso VARCHAR2(1) := fug_obt_fre_proceso('PRC_DEB_CHQ_MON_INFERIOR');
  v_db_prod     VARCHAR2(1) := fug_ind_produccion;
  v_val_exo_cargo    ge_movimientos.val_tasa%type;
  v_val_exo_impuesto ge_movimientos.val_tasa%type;
  v_tip_valor        ge_tasas.tip_valor%type;
  v_redondeo         number(3) := 0;
  
CURSOR c_CHQ IS
 SELECT cu.cod_modulo, cu.cod_modalidad, cu.cod_sub_modalidad, cu.cod_oficina, cu.cod_moneda,
        c.NRO_CUENTA, p.tipo, count(*) CANTIDAD
   FROM BA_PERSONAS P, GE_CUENTAS CU, GE_CTA_CLIENTES CL, CC_CHE_PAGADOS C
  WHERE c.fecha between to_Date('01'||to_char(pag_cal.fu_obt_fec_actual(4),'mmyyyy'),'ddmmyyyy')
    and last_day(pag_cal.fu_obt_fec_actual(4))
    and CL.NRO_CUENTA = C.Nro_Cuenta
    and cl.relacion   = 'P'
    and p.cod_persona = cl.cod_persona
    and ((p.tipo = 'F'
    and C.monto < fug_obt_pardinamico('MTO_MIN_CHQ_PER_FISICA'))
     or (p.tipo = 'J'
    and C.monto < fug_obt_pardinamico('MTO_MIN_CHQ_PER_JURIDICA')))
    and cu.nro_cuenta = c.nro_cuenta
    and cu.cod_modalidad = 41
    and cu.cod_moneda = pag_gen.fu_obt_mon_local
    and cu.estado not in ('C','P','A','T','D','X')
  group by cu.cod_modulo, cu.cod_modalidad, cu.cod_sub_modalidad, cu.cod_oficina, cu.cod_moneda,
        c.nro_cuenta, p.tipo;


-----
-- Procedimientos Internos
----
PROCEDURE PR_OBT_CARGOS
 (P_COD_OFI_ORIGEN IN GE_CUENTAS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MONEDA IN GE_CUENTAS.COD_MONEDA%TYPE
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 ,P_COD_MODULO IN GE_CUENTAS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE
 ,P_COD_TRA_CARGO IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
 ,P_IVA_INCLUIDO  IN VARCHAR2 DEFAULT 'S'
 ,P_COD_TAS_CARGO OUT GE_MOVIMIENTOS.COD_TASA%TYPE
 ,P_VAL_TAS_CARGO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 ,P_VAL_CARGO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 ,P_COD_TRA_IMPUESTO OUT GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
 ,P_COD_TAS_IMPUESTO OUT GE_MOVIMIENTOS.COD_TASA%TYPE
 ,P_VAL_TAS_IMPUESTO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 ,P_VAL_IMPUESTO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 )
 IS
--v_mto_exonerado number(21,2);
v_val_base      number(18,2) := p_monto;
v_fec_vigencia  date;
v_tip_valor     varchar2(1);
v_tipo          varchar2(1);
v_redondeo      number(1);
v_tas_personalizada varchar2(1);
begin
  -- veo si la cuenta tiene transaccion prohibida
  if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                 p_cod_tra_cargo,
                                 p_cod_modulo,
                                 p_cod_modalidad) = 'N' then
    -- no tiene transaccion prohibida, se calcula
    begin
       select tas_personalizada
         into v_tas_personalizada
         from ge_cuentas
         where nro_cuenta = p_nro_cuenta;
    exception
       when no_data_found then
          raise_application_error(-20000,'Cuenta '||p_nro_cuenta||' no registrada');
    end;
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',P_COD_MODULO,P_COD_MODALIDAD,P_cod_moneda);
    -- busco el valor de la tasa
    pag_gen.pr_obt_val_tasa(p_cod_modulo, p_cod_modalidad,
         p_cod_ofi_origen, p_nro_cuenta, p_cod_moneda,
         v_val_base, nvl(v_tas_personalizada,'N'), p_cod_tas_cargo,
         p_cod_tra_cargo, trunc(sysdate),
         p_val_tas_cargo, v_fec_vigencia, v_tip_valor, v_tipo);    ---OUT
    if v_tip_valor = 'V' then
       -- si es un valor, se toma directamente
       p_val_cargo := nvl(p_val_tas_cargo,0);
    else
       -- es un porcentaje
       p_val_cargo := round(nvl(v_val_base,0)*
                               nvl(p_val_tas_cargo,0)/100,v_redondeo);
      --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
      p_val_cargo := pag_gen.FU_OBT_VAL_FINAL(p_val_cargo);
    end if;

    -- busco el impuesto asociado a este cargo
    begin
      select cod_tra_hijo
        into p_cod_tra_impuesto
        from ge_transacciones_det
       where cod_modulo = p_cod_modulo
         and cod_modalidad = p_cod_modalidad
         and cod_transaccion = p_cod_tra_cargo
         and cod_mod_hijo = p_cod_modulo
         and cod_mad_hijo = p_cod_modalidad
         and rownum = 1;
      -- veo si la cuenta tiene exoneracion de impuestos
      if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                      p_cod_tra_impuesto,
                                      p_cod_modulo,
                                      p_cod_modalidad) = 'N' then
         -- Se encontró impuesto asociado, se calcula
         pag_gen.pr_obt_val_tasa(p_cod_modulo, p_cod_modalidad,
               p_cod_ofi_origen, p_nro_cuenta, p_cod_moneda,
               p_val_cargo, nvl(v_tas_personalizada,'N'), p_cod_tas_impuesto,
               p_cod_tra_impuesto, trunc(sysdate),
               p_val_tas_impuesto, v_fec_vigencia, v_tip_valor, v_tipo);    ---OUT
         if v_tip_valor = 'V' then
            -- si es un valor, se toma directamente
            p_val_impuesto := nvl(p_val_tas_impuesto,0);
         else
            --
            -- es un porcentaje, se considera incluido en el cargo
              p_val_impuesto := round(nvl(p_val_cargo,0)*
                                      nvl(p_val_tas_impuesto,0)/(100+p_val_tas_impuesto),v_redondeo);
            --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
              p_val_impuesto := pag_gen.FU_OBT_VAL_FINAL(p_val_impuesto);
         end if;

         -- resto el monto del impuesto al cargo, porque va incluido
         if nvl(p_iva_incluido,'S') = 'S' then
            p_val_cargo := nvl(p_val_cargo,0) - nvl(p_val_impuesto,0);
         end if;
         if p_val_cargo < 0 then
            raise_application_error(-20000,'Impuesto mas alto que el Cargo');
         end if;
       else
          p_val_impuesto := 0;
       end if;
    exception
       when no_data_found then
          p_val_impuesto := 0;
       when others then
          raise_application_error(-20000,'Al leer Impuesto '||sqlerrm);
    end;
  end if;
end ;

PROCEDURE PR_VER_CHQ_EXENTOS
 (P_COD_tASA      IN GE_TASAS.COD_TASA%TYPE
 ,P_NRO_CUENTA    IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MODULO    IN GE_CUENTAS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE
 ,P_COD_SUB_MODALIDAD IN GE_CUENTAS.COD_SUB_MODALIDAD%TYPE
 ,P_COD_OFICINA   IN GE_CUENTAS.COD_OFICINA%TYPE
 ,P_COD_MONEDA    IN GE_CUENTAS.COD_MONEDA%TYPE
 ,P_FECHA         IN DATE
 ,P_CANTIDAD  OUT GE_TAS_FECHAS.VAL_TASA%TYPE
 )
 IS
 v_cod_ente ge_entes.cod_ente%type;
BEGIN
  --
  if P_NRO_CUENTA is not null then
    v_cod_ente := fug_obt_ent_pag_sue(p_nro_cuenta);
  else
    v_cod_ente := null;
  end if;
      BEGIN
         SELECT val_tasa
           INTO p_cantidad
           FROM ge_tas_fechas
          WHERE nvl(cod_modulo,nvl(p_cod_modulo,-1))       = nvl(p_cod_modulo,-1)
            AND nvl(cod_modalidad,nvl(p_cod_modalidad,-1)) = nvl(p_cod_modalidad,-1)
            AND nvl(cod_sub_modalidad,nvl(p_cod_sub_modalidad,-1)) = nvl(p_cod_sub_modalidad,-1)
            AND nvl(cod_oficina,nvl(p_cod_oficina,-1))     = nvl(p_cod_oficina,-1)
            AND nvl(cod_ente,nvl(v_cod_ente,-1))           = nvl(v_cod_ente,-1)
            AND nvl(cod_moneda,nvl(p_cod_moneda,'x'))      = nvl(p_cod_moneda,'x')
            AND nro_cuenta = p_nro_cuenta
            AND cod_tasa = p_cod_tasa
            AND fec_vigencia =(SELECT MAX(fec_vigencia)
                                 FROM  ge_tas_fechas
                                WHERE nvl(cod_modulo,nvl(p_cod_modulo,-1))       = nvl(p_cod_modulo,-1)
                                  AND nvl(cod_modalidad,nvl(p_cod_modalidad,-1)) = nvl(p_cod_modalidad,-1)
                                  AND nvl(cod_sub_modalidad,nvl(P_cod_sub_modalidad,-1)) = nvl(P_cod_sub_modalidad,-1)
                                  AND nvl(cod_oficina,nvl(p_cod_oficina,-1))     = nvl(p_cod_oficina,-1)
                                  AND nvl(cod_ente,nvl(v_cod_ente,-1))           = nvl(v_cod_ente,-1)
                                  AND nvl(cod_moneda,nvl(p_cod_moneda,'x'))      = nvl(p_cod_moneda,'x')
                                  AND nro_cuenta = p_nro_cuenta
                                  AND cod_tasa = p_cod_tasa
                                  AND fec_vigencia <= p_Fecha);
         EXCEPTION
            WHEN NO_dATA_FOUND THEN
               p_cantidad := 0;
            WHEN OTHERS THEN
   	           RAISE_APPLICATION_ERROR(-20003,SQLERRM||' Tasa '||TO_CHAR(p_cod_tasa)||' '||
   	                                          ' - para '||p_cod_moneda||' '||p_Fecha);
      END;

End;

------
-- PROCEDIMIENTO PRINCIPAL
-----
BEGIN
begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 4; end;
  v_hora    := fug_ini_hora(sysdate,'HH24:MI:SS');
  v_nro_Secuencia := 0;
  v_fcdehoy := pag_cal.fu_obt_fec_actual(4);

  --busco oficina origen
  begin
    select cod_oficina
      into v_cod_ofi_origen
      from ba_usuarios
     where cod_usuario = user;
  exception
    when others then
     	raise_application_error(20009,'Al recup. oficina del usuario '||sqlerrm);
  end;

FOR reg in c_chq loop
    --- Recuperar datos de la cuenta
    pag_cta.pr_obt_cuenta(reg.nro_cuenta);
    if pag_cta.g_cod_error <> 0 then
       v_cod_error := 104;
       v_lugar := 'Recup. datos de la cuenta ' || reg.nro_cuenta || ' - ' ||pag_cta.g_msj_error;
       v_hubo_error := 'S';
       goto siguiente;
    end if;
    -- Verificar si la cuenta tiene tasa personalizada
    begin
       select tas_personalizada
         into v_tas_personalizada
         from ge_cuentas
         where nro_cuenta = reg.nro_cuenta;
    exception
       when no_data_found then
          raise_application_error(-20000,'Cuenta '||reg.nro_cuenta||' no registrada');
    end;
    --Verificar si la cuenta no posee cantidad de cheques excentos del cargo :  Tasa 300
    v_can_exento := 0;
    if  v_tas_personalizada = 'S' then
       pr_ver_chq_Exentos(300, reg.nro_cuenta, reg.cod_modulo, reg.cod_modalidad,
                          reg.cod_sub_modalidad, reg.cod_oficina,
                          reg.cod_moneda, v_fcdehoy, v_can_exento);
    End if;
    if reg.cantidad > v_can_Exento then
       v_cantidad := reg.cantidad - v_can_exento;
       --Determinar la transaccion que le corresponde
       If reg.tipo  = 'F' then -- Para personas fisicas
          v_transaccion := 4105; -- Trans. Pers.fisicas
       else
          v_transaccion := 4109; -- Trans. Pers.Juridicas
       end if;
       if v_nro_Secuencia > 990 then
         v_hora    := fug_ini_hora(sysdate,'HH24:MI:SS');--pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);--DYDMR-10233
         v_nro_Secuencia := 0;
       end if;
       v_sal_disponible := pag_cta.G_CTAS.sal_disponible;
       v_estado         := pag_cta.G_CTAS.estado;
      --calcular el monto e impuesto, en base al monto imponible
       begin
         v_lugar := 'cta : '||reg.nro_cuenta||' pr_obt_Cargos';
         PR_OBT_CARGOS(v_cod_ofi_origen,reg.nro_cuenta,reg.cod_moneda,0,pag_cta.G_CTAS.cod_modulo, pag_cta.g_ctas.cod_modalidad,
            v_transaccion, v_iva_incluido,v_cod_tas_cargo, v_val_tas_cargo, v_mto_cargo, v_tra_iva, v_cod_tas_iva, v_val_tas_iva, v_mto_iva);
       exception
         when others then
           v_cod_error := 107;
           v_lugar := sqlerrm;
           v_hubo_error := 'S';
           goto siguiente;
       end;
       --si tiene cantidad
       if v_cantidad > 0 then
          v_mto_cargo := nvl(v_mto_cargo,0) * v_cantidad; --si tiene cantidad se multiplica
          v_mto_iva   := nvl(v_mto_iva,0)   * v_cantidad; --si tiene cantidad se multiplica
       end if;
       --monto operación es el cargo + el impuesto
       v_mto_mov := nvl(v_mto_cargo,0) + nvl(v_mto_iva,0);
       /*
       || PCC-Exoneración y Extorno de Comisiones y Tasas
       || Se ejecuta si el proceso no es mensual
       || o la base de datos no es producción
       */
       IF v_fre_proceso <> 'M' OR v_db_prod = 'N' THEN
          -- busco el valor de la tasa
          begin
             v_val_exo_cargo := fug_obt_val_tasa(pag_cta.G_CTAS.cod_modulo,
                                                 pag_cta.g_ctas.cod_modalidad,
                                                 v_cod_ofi_origen,
                                                 null,
                                                 reg.cod_moneda,
                                                 0, 'N', NULL,
                                                 v_transaccion,
                                                 v_fcdehoy);
          exception
             when others then
                raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
          end;
          -- si tiene cantidad
          if v_cantidad > 0 then
             v_val_exo_cargo := nvl(v_val_exo_cargo,0) * v_cantidad; --si tiene cantidad se multiplica
          end if;
          if v_tra_iva is null then
             begin
                select cod_tra_hijo
                  into v_tra_iva
                  from ge_transacciones_det
                 where cod_modulo      = pag_cta.G_CTAS.cod_modulo
                   and cod_modalidad   = pag_cta.g_ctas.cod_modalidad
                   and cod_transaccion = v_transaccion
                   and cod_mod_hijo    = pag_cta.G_CTAS.cod_modulo
                   and cod_mad_hijo    = pag_cta.g_ctas.cod_modalidad
                   and rownum          = 1;
             exception
                when no_data_found then
                   v_tra_iva := null;
                when others then
                   raise_application_error(-20000,'Al Obt.Tra.IVA:'||sqlerrm);
             end;
          end if;
          if v_tra_iva is null then
             v_val_exo_impuesto := 0;
          else
             begin
                v_val_exo_impuesto := fug_obt_val_tasa(pag_cta.G_CTAS.cod_modulo,
                                                       pag_cta.g_ctas.cod_modalidad,
                                                       v_cod_ofi_origen,
                                                       null,
                                                       reg.cod_moneda,
                                                       0, 'N', NULL,
                                                       v_tra_iva,
                                                       v_fcdehoy);
             exception
                when others then
                   raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
             end;
             -- si tiene cantidad
             if v_cantidad > 0 then
                v_val_exo_impuesto := nvl(v_val_exo_impuesto,0) * v_cantidad; --si tiene cantidad se multiplica
             end if;
             if v_cod_tas_iva is null then
                begin
                   select cod_tasa
                     into v_cod_tas_iva
                     from ge_transacciones
                    where cod_modulo      = pag_cta.G_CTAS.cod_modulo
                      and cod_modalidad   = pag_cta.g_ctas.cod_modalidad
                      and cod_transaccion = v_tra_iva;
                exception
                   when no_data_found then
                      v_cod_tas_iva := null;
                   when others then
                      raise_application_error(-20000,'Al Obt.Tasa IVA:'||sqlerrm);
                end;
             end if;
             if v_cod_tas_iva is null then
                v_val_exo_impuesto := 0;
             else
                v_tip_valor := fug_obt_tip_val_tasa(v_cod_tas_iva);
                v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                                  pag_cta.G_CTAS.cod_modulo,
                                                  pag_cta.g_ctas.cod_modalidad,
                                                  pag_cta.g_ctas.cod_moneda);                
                IF v_tip_valor = 'V' THEN
                   -- si es un valor, se toma directamente
                   v_val_exo_impuesto := nvl(v_val_exo_impuesto, 0);
                ELSE
                   -- es un porcentaje
                   v_val_exo_impuesto := round(nvl(v_val_exo_cargo,0)*
                                         nvl(v_val_exo_impuesto,0)/(100+v_val_exo_impuesto),v_redondeo);
                   --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
                   v_val_exo_impuesto := pag_gen.fu_obt_val_final(v_val_exo_impuesto);
                END IF;
             end if;
          end if;
          v_val_exo_cargo := nvl(v_val_exo_cargo,0) - nvl(v_val_exo_impuesto,0);
          if pag_cta.fu_ver_tra_prohibida(reg.nro_cuenta,
                                          v_transaccion,
                                          pag_cta.G_CTAS.cod_modulo,
                                          pag_cta.g_ctas.cod_modalidad) = 'S' then
             prg_ins_exoneracion(v_transaccion, pag_cta.G_CTAS.cod_modulo,
                                 pag_cta.g_ctas.cod_modalidad, reg.cod_moneda,
                                 reg.nro_cuenta, null, v_cod_tas_cargo,
                                 nvl(v_val_exo_cargo, 0),
                                 nvl(v_val_exo_cargo, 0), null,
                                 nvl(v_val_exo_cargo, 0));
          elsif ( nvl(v_mto_cargo, 0) <> nvl(v_val_exo_cargo, 0) ) or
                ( nvl(v_mto_cargo, 0) = 0 and nvl(v_val_exo_cargo, 0) <> 0) then
             prg_ins_exoneracion(v_transaccion, pag_cta.G_CTAS.cod_modulo,
                                 pag_cta.g_ctas.cod_modalidad, reg.cod_moneda,
                                 reg.nro_cuenta, null, v_cod_tas_cargo,
                                 (nvl(v_val_exo_cargo, 0) - nvl(v_mto_cargo, 0)),
                                  v_val_exo_cargo, null,
                                 (nvl(v_val_exo_cargo, 0) - nvl(v_mto_cargo, 0)));
          end if;
          if pag_cta.fu_ver_tra_prohibida(reg.nro_cuenta,
                                          v_tra_iva,
                                          pag_cta.G_CTAS.cod_modulo,
                                          pag_cta.g_ctas.cod_modalidad) = 'S' then
             prg_ins_exoneracion(v_tra_iva, pag_cta.G_CTAS.cod_modulo,
                                 pag_cta.g_ctas.cod_modalidad, reg.cod_moneda,
                                 reg.nro_cuenta, null, v_cod_tas_iva,
                                 nvl(v_val_exo_impuesto, 0),
                                 nvl(v_val_exo_impuesto, 0), null,
                                 nvl(v_val_exo_impuesto, 0));
          elsif pag_cta.fu_ver_tra_prohibida(reg.nro_cuenta,
                                             v_transaccion,
                                             pag_cta.G_CTAS.cod_modulo,
                                             pag_cta.g_ctas.cod_modalidad) = 'S' then
             null;
          elsif ( nvl(v_mto_iva, 0) <> nvl(v_val_exo_impuesto, 0) ) or
                ( nvl(v_mto_iva, 0) = 0 and nvl(v_val_exo_impuesto, 0) <> 0 ) then
             prg_ins_exoneracion(v_tra_iva, pag_cta.G_CTAS.cod_modulo,
                                 pag_cta.g_ctas.cod_modalidad, reg.cod_moneda,
                                 reg.nro_cuenta, null, v_cod_tas_iva,
                                 (nvl(v_val_exo_impuesto, 0) - nvl(v_mto_iva, 0)),
                                  v_val_exo_impuesto, null,
                                 (nvl(v_val_exo_impuesto, 0) - nvl(v_mto_iva, 0)));
          end if;
       end if;
       --<
       --si el saldo es suficiente, genera el movimiento
       if v_mto_cargo > 0 and v_sal_disponible >= v_mto_mov then
          --- Actualizar los datos de las cuentas con movimientos.
          if v_nro_Secuencia > 990 then
            v_hora := fug_ini_hora(sysdate,'HH24:MI:SS'); --pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);--DYDMR-10233
            v_nro_secuencia := -999;
          end if;
          v_lugar := '1- PR_aCT_OPERACION';
          PAG_CTA.PR_ACT_OPERACION
               (reg.nro_cuenta      -- P_NRO_CUENTA
               ,v_hora        -- P_HORA
               ,'D'           -- P_TIP_MOVIMIENTO
               ,pag_cta.G_CTAS.cod_moneda  -- P_COD_MONEDA
               ,v_mto_cargo     -- P_MONTO
               ,v_transaccion   -- P_COD_TRA_PADRE
               ,v_transaccion   -- P_COD_TRANSACCION
               ,null  --P_NRO_DOCUMENTO
               ,null          --P_COTIZACION
               ,pag_cta.g_ctas.cod_oficina  -- P_COD_OFI_ORIGEN
               ,pag_cta.g_Ctas.cod_modulo   -- P_COD_MOD_PADRE
               ,pag_cta.g_ctas.cod_modalidad  -- P_COD_MAD_PADRE
               ,v_cod_tas_cargo          --P_COD_TASA
               ,v_val_tas_cargo          --P_VAL_TASA
               ,'CARGO EMISION DE CHEQUE MONTO INFERIOR' -- P_CONCEPTO
               ,'N'           -- p_EMI_AVISO
               ,v_nro_secuencia -- P_NRO_SECUENCIA IN OUT
               ,v_fcdehoy       -- P_FEC_VALOR
               ,null          -- P_COD_BANCO
               ,null          -- P_COD_CAUSA
               ,null);        -- P_MTO_EQU_LOCAL

          if pag_cta.fu_obt_cod_error() <> 0 then
            v_cod_error := pag_cta.G_COD_ERROR;
            v_lugar := 'Mov.Cta.(cargo) '||pag_cta.fu_obt_msj_error();
            v_hubo_error := 'S';
            goto siguiente;
          end if;
          if v_mto_iva > 0 then --generar movimiento x el iva
            --- Actualizar los datos de las cuentas con movimientos.
            if v_nro_Secuencia > 990 then
              v_hora := fug_ini_hora(sysdate,'HH24:MI:SS');--pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);--DYDMR-10233
              v_nro_secuencia := -999;
            end if;
            v_lugar := '2- PR_ACT_OPERACION';
            PAG_CTA.PR_ACT_OPERACION
                 (reg.nro_cuenta      -- P_NRO_CUENTA
                 ,v_hora        -- P_HORA
                 ,'D'           -- P_TIP_MOVIMIENTO
                 ,pag_cta.g_ctas.cod_moneda  -- P_COD_MONEDA
                 ,v_mto_iva    -- P_MONTO
                 --,v_transaccion -- P_COD_TRA_PADRE
                 ,v_tra_iva     --  P_COD_TRA_PADRE
                 ,v_tra_iva     --  P_COD_TRANSACCION
                 ,null  --P_NRO_DOCUMENTO
                 ,null          --P_COTIZACION
                 ,pag_cta.g_ctas.cod_oficina  -- P_COD_OFI_ORIGEN
                 ,pag_Cta.g_Ctas.cod_modulo   -- P_COD_MOD_PADRE
                 ,pag_Cta.g_ctas.cod_modalidad -- P_COD_MAD_PADRE
                 ,v_cod_tas_iva          --P_COD_TASA
                 ,v_val_tas_iva          --P_VAL_TASA
                 ,'IVA S/ CARGO EMISION DE CHEQUE MONTO INFERIOR' -- P_CONCEPTO
                 ,'N'           -- p_EMI_AVISO
                 ,v_nro_secuencia -- P_NRO_SECUENCIA IN OUT
                 ,v_fcdehoy      -- P_FEC_VALOR
                 ,null          -- P_COD_BANCO
                 ,null          -- P_COD_CAUSA
                 ,null);        -- P_MTO_EQU_LOCAL

            if pag_cta.fu_obt_cod_error() <> 0 then
              v_cod_error := pag_cta.G_COD_ERROR;
              v_lugar := 'Mov.Cta.(iva) '||pag_cta.fu_obt_msj_error();
              v_hubo_error := 'S';
              goto siguiente;
            end if;
          end if;
       ELSE   -- si no tiene saldo suficiente se graba como pendiente   
         If v_mto_mov > 0 then
           -- RI : 02/02/2010 : Si la cuenta esta inactiva y no tiene saldo no se graba mov.pendiente
           If  v_sal_disponible = 0 and v_estado = 'I' then
               null;
           else
            Insert into Ge_Mov_Pendientes
            (nro_cuenta,Fecha,Cod_modulo,Cod_modalidad,Cod_transaccion,
             Cod_mod_padre,Cod_mad_padre,Cod_tra_padre,Monto,
             Hora,Cod_usuario,
             Cod_moneda,Cod_oficina,Estado,Cod_ofi_origen,
             Concepto,
             Cod_tasa,Val_tasa,Nro_documento,saldo)
            Values
             (reg.nro_cuenta,v_fcdehoy,pag_cta.g_Ctas.cod_modulo,pag_cta.g_Ctas.cod_modalidad,v_transaccion,
              pag_cta.g_Ctas.cod_modulo,pag_cta.g_Ctas.cod_modalidad,v_transaccion,nvl(v_mto_mov,0),
              v_hora,user,
              pag_cta.g_ctas.cod_moneda,pag_cta.G_CTAS.cod_oficina,'I',pag_cta.g_ctas.cod_oficina,
              'CARGO EMISION CHEQ. MONTO INFERIOR',
              v_cod_tas_cargo, v_val_tas_cargo,null,nvl(v_mto_mov,0));
            End if;  
         End if;   
       END IF;  
   END IF;
      --- Siguiente registro
      <<siguiente>>
      null;

  END LOOP;

EXCEPTION
  when no_data_found then
     if nvl(v_db_prod,'N') = 'S' then
        raise_application_error(-20000,'No existe datos en el archivo');
     end if;
end;
/

