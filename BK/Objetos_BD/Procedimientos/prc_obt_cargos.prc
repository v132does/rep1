CREATE OR REPLACE PROCEDURE IT.PRC_OBT_CARGOS
 (P_COD_OFI_ORIGEN IN GE_CUENTAS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MONEDA IN GE_CUENTAS.COD_MONEDA%TYPE
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 ,P_MONTO2 IN GE_MOVIMIENTOS.MONTO%TYPE
 ,P_COD_MODULO IN GE_CUENTAS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE
 ,P_COD_TRA_CARGO IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
 ,P_COD_TAS_CARGO OUT GE_MOVIMIENTOS.COD_TASA%TYPE
 ,P_VAL_TAS_CARGO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 ,P_VAL_CARGO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 ,P_COD_TRA_IMPUESTO OUT GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
 ,P_COD_TAS_IMPUESTO OUT GE_MOVIMIENTOS.COD_TASA%TYPE
 ,P_VAL_TAS_IMPUESTO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 ,P_VAL_IMPUESTO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 ,P_VAL_HASTA    OUT GE_TAS_RANGOS.VAL_HASTA%TYPE
 )
 IS
v_mto_exonerado number(21,2);
v_val_base      number(18,2) := p_monto;
v_fec_vigencia  date;
v_tip_valor     varchar2(1);
v_tipo          varchar2(1);
v_redondeo      number(1);
v_tas_personalizada varchar2(1);
--
-- Procedimiento Interno
--
  procedure pr_obt_val_has_ant
 (P_COD_OFICINA       IN BA_OFICINAS.COD_OFICINA%TYPE
 ,P_valor             IN NUMBER default 0
 ,p_cod_tasa          in ge_movimientos.val_tasa%type
 ,p_val_has_ant       out ge_tas_rangos.val_hasta%type
) is
  v_cod_sub_modalidad number(5) := fug_obt_cod_sub_modalidad(p_nro_cuenta);
  v_cod_ente ge_entes.cod_ente%type;
  begin
    if P_NRO_CUENTA is not null then
      v_cod_ente := fug_obt_ent_pag_sue(p_nro_cuenta);
    else
      v_cod_ente := null;
    end if;
    --
    DECLARE CURSOR rango IS
       SELECT val_hasta
         FROM ge_tas_rangos
        WHERE nvl(cod_modulo,nvl(p_cod_modulo,-1))       = nvl(p_cod_modulo,-1)
          AND nvl(cod_modalidad,nvl(p_cod_modalidad,-1)) = nvl(p_cod_modalidad,-1)
          AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
          AND nvl(cod_oficina,nvl(p_cod_oficina,-1))     = nvl(p_cod_oficina,-1)
          AND nvl(cod_ente,nvl(v_cod_ente,-1))           = nvl(v_cod_ente,-1)
          AND nvl(cod_moneda,nvl(p_cod_moneda,'x'))      = nvl(p_cod_moneda,'x')
          AND nro_cuenta = p_nro_cuenta
          AND cod_tasa =  p_cod_tasa
          AND val_hasta <= NVL(p_valor,0)
          and nvl(val_Tasa,0) = 0   -- busca la cantidad de cheques que son excentos de cargo
          AND fec_vigencia <= trunc(sysdate)
       ORDER BY DECODE(COD_MODULO, NULL, 0, 1) +
                DECODE(COD_MODALIDAD, NULL, 0, 1) +
                DECODE(COD_SUB_MODALIDAD, NULL, 0, 1) DESC, fec_vigencia DESC, val_hasta ASC;

        BEGIN
           IF rango%isopen THEN
              CLOSE rango;
           END IF;
           OPEN rango;
              FETCH rango INTO p_val_has_ant;
              IF RANGO%NOTFOUND THEN
                 DECLARE
                   CURSOR rango2 is
                     SELECT val_hasta
                       FROM ge_tas_rangos
                      WHERE nvl(cod_modulo,nvl(p_cod_modulo,-1))       = nvl(p_cod_modulo,-1)
                        AND nvl(cod_modalidad,nvl(p_cod_modalidad,-1)) = nvl(p_cod_modalidad,-1)
                        AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
                        AND nvl(cod_oficina,nvl(p_cod_oficina,-1))     = nvl(p_cod_oficina,-1)
                        AND nvl(cod_ente,nvl(v_cod_ente,-1))           = nvl(v_cod_ente,-1)
                        AND nvl(cod_moneda,nvl(p_cod_moneda,'x'))      = nvl(p_cod_moneda,'x')
                        AND nro_cuenta is null
                        and cod_persona is null
                        AND cod_tasa =  p_cod_tasa
                        AND val_hasta <= NVL(p_valor,0)
                        and nvl(val_Tasa,0) = 0   -- busca la cantidad de cheques que son excentos de cargo
                        AND fec_vigencia <= trunc(sysdate)
                     ORDER BY DECODE(COD_MODULO, NULL, 0, 1) +
                              DECODE(COD_MODALIDAD, NULL, 0, 1) +
                              DECODE(COD_SUB_MODALIDAD, NULL, 0, 1) DESC, fec_vigencia DESC, val_hasta ASC;
                 BEGIN
                   If rango2%isopen then
                      close rango2;
                   End if;
                   Open rango2;
                      FETCH rango2 INTO p_val_has_ant;
                      IF RANGO2%NOTFOUND THEN
                         p_val_has_ant := 0;
                      End if;
                      Close Rango2;
                 END;
                 --p_val_has_ant := 0;
              END IF;
           CLOSE RANGO;
        END;
  End;
--
--  PROCEDIMIENTO PRINCIPAL
--
BEGIN
  -- veo si la cuenta tiene transaccion prohibida
  if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                 p_cod_tra_cargo,
                                 p_cod_modulo,
                                 p_cod_modalidad) = 'N' then
    if p_nro_cuenta is not null then
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
    end if;
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',p_cod_modulo,p_cod_modalidad,p_cod_moneda);
    -- busco el valor de la tasa
    pag_gen.pr_obt_val_tasa(p_cod_modulo, p_cod_modalidad,
         p_cod_ofi_origen, p_nro_cuenta, p_cod_moneda,
         v_val_base, nvl(v_tas_personalizada,'N'), p_cod_tas_cargo,
         p_cod_tra_cargo, trunc(sysdate),
         p_val_tas_cargo, v_fec_vigencia, v_tip_valor, v_tipo);    ---OUT
    if v_tip_valor = 'V' then
       -- si es un valor, se toma directamente
       p_val_cargo := nvl(p_val_tas_cargo,0);
    elsif v_tip_Valor = 'T' then  -- es un codigo de tasa
       --si es un codigo de tasa hay que ir a buscar el valor con la tasa devuelta y
       --con el el p_monto2
        If  nvl(p_val_Tas_Cargo,0) > 0 then
          p_cod_tas_cargo := p_val_tas_cargo;
          pag_gen.pr_obt_val_tasa(p_cod_modulo, p_cod_modalidad,
             p_cod_ofi_origen, p_nro_cuenta, p_cod_moneda,
             p_monto2, nvl(v_tas_personalizada,'N'), p_val_tas_cargo,
             p_cod_tra_cargo, trunc(sysdate),
             p_val_tas_cargo, v_fec_vigencia, v_tip_valor, v_tipo);    ---OUT
          if  v_tip_Valor = 'V' then
            p_val_cargo := nvl(p_val_Tas_Cargo,0);
          elsif v_tip_valor = 'C' then
            p_val_cargo := round(nvl(p_monto2,0) * nvl(p_val_Tas_Cargo,0),v_redondeo);
          else
           -- es un porcentaje
           p_val_cargo := round(nvl(v_val_base,0)*
                                   nvl(p_val_tas_cargo,0)/100,v_redondeo);
          --verificar si el monto a cobrar est¿ limitado x el m¿nimo y m¿ximo de la tasa
          p_val_cargo := round(pag_gen.FU_OBT_VAL_FINAL(p_val_cargo),v_redondeo);
          end if;
          ---Obtengo el rango anterior al devuelto
          pr_obt_val_has_ant(p_cod_ofi_origen, pag_gen.g_val_hasta, p_cod_tas_cargo, p_val_hasta);
       else
          p_Val_cargo := 0;
       end if;
    else
       -- es un porcentaje
       p_val_cargo := round(nvl(v_val_base,0)*
                               nvl(p_val_tas_cargo,0)/100,v_redondeo);
      --verificar si el monto a cobrar est¿ limitado x el m¿nimo y m¿ximo de la tasa
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
         and cod_tra_hijo <> p_cod_tra_cargo -- Que la transacci¿n hijo sea diferente de la padre PV 02/11/09
         and rownum = 1;
      -- veo si la cuenta tiene exoneracion de impuestos
      if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                      p_cod_tra_impuesto,
                                      p_cod_modulo,
                                      p_cod_modalidad) = 'N' then
         -- Se encontro impuesto asociado, se calcula
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

            --verificar si el monto a cobrar est¿ limitado x el m¿nimo y m¿ximo de la tasa
            p_val_impuesto := pag_gen.FU_OBT_VAL_FINAL(p_val_impuesto);
         end if;

         -- resto el monto del impuesto al cargo, porque va incluido
         p_val_cargo := nvl(p_val_cargo,0) - nvl(p_val_impuesto,0);
         if p_val_cargo < 0 then
            raise_application_error(-20000,'Cta:'||p_nro_cuenta||' Trans.'||P_COD_TRA_CARGO||'Impuesto mas alto que el Cargo '||p_val_cargo||' Imp '||p_val_impuesto);
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
  p_val_cargo := round(p_val_cargo,v_redondeo);
  p_val_impuesto := round(p_val_impuesto, v_redondeo);
exception
  when others then
    IF sqlcode <= -20000 THEN
      raise;
    else
      raise_application_error(-20000,'En obtener cargos por pago de cheques'||' - '||sqlerrm);
    End if;
end ;
/

