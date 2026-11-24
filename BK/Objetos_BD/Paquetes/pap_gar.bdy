CREATE OR REPLACE PACKAGE BODY IT.PAP_GAR IS
/* Obtener moneda de la línea. */
/* Verificar si el crédito posee linea y actualizar el mto aplicado. */
/* Verificar si el crédito posee garantia y actualizar el mto aplicado. */
/* Actualizar el mto aplicado de tipos de garantia por limite */
FUNCTION FU_OBT_MON_LINEA
 (P_NRO_LINEA IN PR_LINEAS.NRO_LINEA%TYPE
 )
 RETURN VARCHAR2
 IS
v_cod_moneda pr_lineas.cod_moneda%type;
BEGIN
   select cod_moneda
     into v_cod_moneda
     from pr_lineas
    where nro_linea = p_nro_linea;
    return v_cod_moneda;
exception
   when no_data_found then
      raise_application_error(-20000, 'Linea no registrada '||p_nro_linea);
   when others then
      raise_application_error(-20000,'Rec.Mon.Linea '||sqlerrm);
END;
FUNCTION FU_OBT_MON_GARANTIA
 (P_NRO_GARANTIA IN PR_GARANTIAS.NRO_GARANTIA%TYPE
 )
 RETURN VARCHAR2
 IS
V_COD_MONEDA BA_MONEDAS.COD_MONEDA%TYPE;
BEGIN
   select cod_moneda
     into v_cod_moneda
     from pr_garantias
    where nro_garantia = p_nro_garantia;
    return v_cod_moneda;
exception
   when no_data_found then
      raise_application_error(-20000, 'Garantia no registrada '||p_nro_garantia);
   when others then
      If sqlcode <= -20000 then
        raise;
      else
        raise_application_error(-20000,'Rec.Mon.Garantia '||sqlerrm);
      End if;
END;
/* Obtener monto computable de la garantia */
FUNCTION FU_OBT_VAL_COMPUTABLE
 (P_NRO_GARANTIA IN PR_GARANTIAS.NRO_GARANTIA%TYPE
 )
 RETURN NUMBER IS
   v_cod_garantia pr_garantias.cod_garantia%type;
   v_nom_tab_anexa pr_gar_tipos.nom_tab_anexa%type;
   v_cod_moneda pr_garantias.cod_moneda%type;
   v_cod_mon_tasacion pr_garantias.cod_mon_tasacion%type;
   v_valor pr_garantias.valor%type;
   v_mto_riesgo pr_cta_garantias.mto_riesgo%type;
   v_val_tasacion pr_garantias.val_tasacion%type;
   v_monto pr_garantias.mto_aplicado%type;
   v_porcbcp pr_gar_tipos.por_bco_central%type;
   v_computa pr_gar_tipos.computable%type;
   v_val_seguro varchar2(1) := 'N';
   v_val_vta_rapida varchar2(1) := 'N';
   v_val_computable pr_garantias.mto_aplicado%type;
   v_vta_rapida pr_gar_hipotecarias.val_vta_rapida%type;
   v_fec_vto_escritura pr_garantias.fec_vencimiento%type;
   v_fec_actual ge_calendarios.fec_actual%type;
   r_pghip pr_gar_hipotecarias%rowtype;
   v_estado pr_garantias.estado%type;
   v_cod_gar_hip_vivienda pr_garantias.cod_garantia%type := to_number(fug_obt_pardinamico('COD_GAR_HIP_VIVIENDA', 6));
   v_val_tas_calculado pr_garantias.valor%type; 
   v_cod_gar_fogapy      ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_GAR_FOGAPY');
   v_msj_error  varchar2(4000) := null;  
   --- Cursor de datos de la hipoteca
   cursor c_hipotecas is
   select *
   from pr_gar_hipotecarias
   where nro_garantia = p_nro_garantia;
   --- OBS: Retorna el valor computable en la moneda de la garantia
BEGIN
   v_val_seguro     := fug_obt_pardinamico('VAL_SEG_CAL_COMPUTABLE', null, null, null);
   v_val_vta_rapida := fug_obt_pardinamico('VAL_VTA_CAL_COMPUTABLE', null, null, null);
   v_fec_actual     := pag_cal.FU_OBT_FEC_ACTUAL(6);
   --- Recuperar datos de la garantia
   begin
      select cod_garantia, cod_moneda, nvl(valor,0), cod_mon_tasacion,
             nvl(val_tasacion,0), fec_vencimiento, estado
        into v_cod_garantia, v_cod_moneda, v_valor, v_cod_mon_tasacion,
             v_val_tasacion, v_fec_vto_escritura, v_estado 
        from pr_garantias
       where nro_garantia = p_nro_garantia;
      exception
         when no_data_found then
            raise_application_error(-20000, 'Garantia '||p_nro_garantia||' no registrada');
   end;
   --
   v_nom_tab_anexa := fup_obt_nom_tab_anexa(v_cod_garantia);
   --- Solo si la escritura o la garantia no esta vencida y solo las confirmadas.
   if nvl(v_fec_vto_escritura, v_fec_actual) >= v_fec_actual /*and v_estado = 'C'*/ then
     begin
        select por_bco_central, computable
          into v_porcbcp, v_computa
          from pr_gar_tipos
         where cod_garantia = v_cod_garantia;
        exception
           when no_data_found then
              raise_application_error(-20000, 'Tipo '||v_cod_garantia||' no registrado');
     end;
      --If v_cod_garantia = 3 THEN  --- HIPOTECARIAS
     if v_nom_tab_anexa = 'PR_GAR_HIPOTECARIAS' then
        v_vta_rapida   := 0;
        v_val_tasacion := 0;
          for gar in c_hipotecas loop
           if (nvl(gar.fec_vencimiento,v_fec_actual-1)  < v_fec_actual
               or nvl(gar.fec_vto_seguro, v_fec_actual) < v_fec_actual) 
               and gar.fec_inscripcion is not null then
              --- Si la tasacion o el seguro se encuentran vencidos se toma el valor
              --- del terreno como valor de la tasacion
              If fug_obt_tip_implementacion in (7) then
                 v_val_tasacion := NVL(v_val_tasacion,0);
              Else
                 --bbvades-2651
                 --si no tiene datos del seguro
                 --entonces se considera el valor edilicio (+) el valor del terreno
                 if gar.val_seguro is null 
                    and gar.fec_vto_seguro is null 
                    and gar.cod_ent_seguro is null then
                       IF v_cod_garantia = v_cod_gar_hip_vivienda THEN -- Res. 12
                          v_val_tasacion := nvl(v_val_tasacion, 0) + nvl(gar.val_vta_rapida, 0);
                       ELSE   
                          v_val_tasacion := NVL(v_val_tasacion,0) + nvl(gar.val_terreno,0) + nvl(gar.val_edilicio,0);
                       END IF;   
                  --si tiene valor edilicio
                 --y el seguro está vencido
                 --y/o alguno de los datos asociados al seguro no se encuentra registrado
                 --entonces sólo se considera el valor del terreno
                  elsif (gar.val_edilicio is not null 
                     and nvl(gar.fec_vto_seguro, v_fec_actual) < v_fec_actual)
                      or gar.val_seguro is null 
                      or gar.fec_vto_seguro is null 
                      or gar.cod_ent_seguro is null then
                     IF v_cod_garantia = v_cod_gar_hip_vivienda THEN -- Res. 12
                        v_val_tasacion := nvl(v_val_tasacion, 0) + least(nvl(gar.val_terreno, 0), nvl(gar.val_vta_rapida, 0));
                     ELSE
                        v_val_tasacion := NVL(v_val_tasacion,0) + nvl(gar.val_terreno,0);
                     END IF;                        
                 end if;
              End if;
           elsif gar.fec_inscripcion is not null Then--si no está vencida la garantia o el seguro
              --si el seguro está vigente              
              if nvl(gar.fec_vto_seguro, v_fec_actual) > v_fec_actual then
                 --si el valor del seguro es menor al valor edilicio
                 --entonces se considera el valor del seguro (+) el valor del terreno
                 if nvl(gar.val_seguro,0) < nvl(gar.val_edilicio,0) then
                    IF v_cod_garantia = v_cod_gar_hip_vivienda THEN -- Res. 12
                       v_val_tasacion := nvl(v_val_tasacion, 0) + least((nvl(gar.val_terreno, 0) + nvl(gar.val_seguro,0)), nvl(gar.val_vta_rapida, 0));
                    ELSE   
                       v_val_tasacion := NVL(v_val_tasacion,0) + nvl(gar.val_terreno,0) + nvl(gar.val_seguro,0);
                    END IF;   
                 else
                    IF v_cod_garantia = v_cod_gar_hip_vivienda THEN
                       v_val_tasacion := nvl(v_val_tasacion, 0) + least((nvl(gar.val_terreno, 0) + nvl(gar.val_edilicio,0)), nvl(gar.val_vta_rapida, 0));
                    ELSE
                       v_val_tasacion := NVL(v_val_tasacion,0) + nvl(gar.val_terreno,0) + nvl(gar.val_edilicio,0);
                    END IF;   
                 end if;
              elsif nvl(gar.fec_vencimiento,v_fec_actual-1) > v_fec_actual then
                 --> Solo debe tener valor computable si tiene valor edilicio y tiene cargado datos de la aseguradora O
                 --> si tiene cargado fecha de incripción.-
                 If nvl(gar.val_edilicio,0) <> 0 and nvl(gar.val_seguro,0) <> 0 Then
                    --> Si el mto asegurado es menor al valor edilicio, suma el valor terreno con el mto. asegurado.-
                    If nvl(gar.val_seguro,0) < nvl(gar.val_edilicio,0) Then
                       IF v_cod_garantia = v_cod_gar_hip_vivienda THEN -- Res. 12
                          v_val_tasacion := nvl(v_val_tasacion, 0) + least((nvl(gar.val_terreno, 0) + nvl(gar.val_seguro,0)), nvl(gar.val_vta_rapida, 0));
                       ELSE
                          v_val_tasacion := NVL(v_val_tasacion,0) + nvl(gar.val_seguro,0) + nvl(gar.val_terreno,0);
                       END IF;   
                    Else
                       IF v_cod_garantia = v_cod_gar_hip_vivienda THEN
                          v_val_tasacion := nvl(v_val_tasacion, 0) + least((nvl(gar.val_terreno, 0) + nvl(gar.val_edilicio,0)), nvl(gar.val_vta_rapida, 0));
                       ELSE
                          v_val_tasacion := NVL(v_val_tasacion,0) + nvl(gar.val_terreno,0) + nvl(gar.val_edilicio,0);
                       END IF;   
                    End If;
                 Else
                    IF v_cod_garantia = v_cod_gar_hip_vivienda THEN -- Res. 12
                       v_val_tasacion := nvl(v_val_tasacion,0) + least(nvl(gar.val_terreno, 0), nvl(gar.val_vta_rapida, 0));
                    ELSE   
                       v_val_tasacion := NVL(v_val_tasacion,0) + nvl(gar.val_terreno,0);
                    END IF;   
                 End IF;
                 
              end if;
           end if;
           v_vta_rapida := nvl(v_vta_rapida,0) + nvl(gar.val_vta_rapida,0);
        end loop;
   	    v_val_tasacion  := NVL(v_val_tasacion,0) * v_PORCBCP / 100;
        --- Actualizar el valor de la tasacion al valor de la garantia para comparar
        --- El valor de venta rapida esta en la misma moneda que la tasación
        v_val_tasacion := pag_gen.FU_CON_MON_A_MONEDA(v_cod_mon_tasacion, v_cod_moneda, v_val_tasacion);
        v_vta_rapida   := pag_gen.FU_CON_MON_A_MONEDA(v_cod_mon_tasacion, v_cod_moneda, v_vta_rapida);
         --Debe asignar como valor computable el menor entre el valor tasacion y escritura
         If v_val_vta_rapida = 'S' and nvl(v_vta_rapida,0) > 0 then
            v_val_computable := least(NVL(v_valor, 0), NVL(v_val_tasacion,0), NVL(v_vta_rapida,0));
         else
           if nvl(v_valor,0) > 0 and nvl(v_val_tasacion,0) > 0 then
              v_val_computable := least(NVL(v_valor,0), NVL(v_val_tasacion,0));
           else
              If fug_obt_tip_implementacion in (1,7) then
                -- Si no tiene tasación debe ser 0 el valor computable.
                if nvl(v_val_tasacion,0) > 0 then
                   v_val_computable := nvl(v_val_tasacion,0);
                else
                   v_val_computable := 0;
                end if;
              else
                if nvl(v_valor,0) > 0 then
                   v_val_computable := nvl(v_valor,0);
                else
                   v_val_computable := nvl(v_val_tasacion,0);
                end if;
              end if;
           end if;
         End if;
        -- Se agregó esta parte para permitir ingresar solicitudes con hipotecas no confirmadas.
        If v_estado != 'C' Then
           If fug_obt_tip_implementacion not in (1,7) then
              v_val_computable := 0;
           Else
              If v_estado != 'I' then
                 v_val_computable := 0;
                 -- Si el estado de la garantia no es ingresada debe devolver 0.
              Elsif nvl(PAE_CNF.G_PROGRAMA,'x') not in ('EPPROCOR', 'EPPROPER', 'PMDESDOC') then
                 v_val_computable := 0;
                 -- Sino es llamado desde las propuestas debe devolver 0.
              Else
                 -- Es llamado desde la solicitud y el estado es Ingresada y tiene 0 como valor computable
                 If v_val_computable = 0 then
                    v_val_computable := nvl(v_valor,0);
                 End if;
              End if;
           End if;
        End if;
     --Elsif v_cod_garantia = 4 and v_estado = 'C' THEN  --- PRENDAS
     Elsif v_nom_tab_anexa = 'PR_GAR_VEHICULOS' and v_estado = 'C' THEN  --- PRENDAS
       IF NVL(v_VAL_TASACION,0) > 0 THEN
          v_val_computable := NVL(v_val_tasacion,0) * v_PORCBCP / 100;
          --- Actualizar el valor computable en la moneda de la garantia
          v_val_computable := pag_gen.FU_CON_MON_A_MONEDA(v_cod_mon_tasacion, v_cod_moneda, v_val_computable);
          If fug_obt_tip_implementacion in (1,7) then
             v_val_computable := least(v_val_computable, v_valor);
          End if;
       ELSE
          if fug_obt_tip_implementacion in (1,7) then
             v_val_computable := 0;
          else
             v_val_computable := NVL(v_valor,0);
          end if;
       END IF;
     Elsif v_nom_tab_anexa = 'PR_GAR_DOCUMENTOS' and v_estado = 'C' and instr(','||v_cod_gar_fogapy||',', ','||v_cod_garantia||',') > 0  then
           begin 
             select sum(nvl(g.mto_riesgo,0))
             into v_mto_riesgo
             from pr_cta_garantias g
             where g.nro_garantia = p_nro_garantia
             and g.cod_garantia = v_cod_garantia;
            exception
              when no_data_found then
                v_mto_riesgo := 0;
              when too_many_rows then
               v_msj_error := 'Nro. De Garantia trae mas de una cuenta: '||' '||p_nro_garantia||' '||sqlerrm;
               v_mto_riesgo := 0;
              when others then
               v_msj_error := 'no encuentra nro_cuenta relacionada a la garantía '||' '||p_nro_garantia||' '||sqlerrm;
               v_mto_riesgo := 0;
            end;
          
           v_val_computable := NVL(v_mto_riesgo,0) * v_PORCBCP / 100;  
             
       
     Else --- OTRAS GARANTIAS
       v_val_computable := NVL(v_valor,0) * v_PORCBCP / 100;
     End If;
   ELSE
      v_val_computable := 0;
   END IF;
   RETURN v_val_computable;
END;
/* Proceso que actualiza el monto aplicado por modalidad */
PROCEDURE PR_ACT_MAD_LIMITE
 (P_NRO_LINEA IN PR_LINEAS.NRO_LINEA%TYPE
 ,P_COD_GARANTIA IN PR_CTA_GARANTIAS.COD_GARANTIA%TYPE
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 ,P_COD_MODULO IN GE_MODALIDADES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE
 )
 IS
v_existe number(01);
BEGIN
   select 1 into v_existe
     from pr_lin_tip_gar_mad
    where nro_linea     = p_nro_linea
      and cod_garantia  = p_cod_garantia
      and cod_modulo    = p_cod_modulo
      and nvl(cod_modalidad,p_cod_modalidad) = p_cod_modalidad
    for update nowait;
   update pr_lin_tip_gar_mad
      set mto_aplicado = nvl(mto_aplicado,0) + p_monto
    where nro_linea    = p_nro_linea
      and cod_garantia = p_cod_garantia
      and cod_modulo   = p_cod_modulo
      and nvl(cod_modalidad,p_cod_modalidad) = p_cod_modalidad;
exception
   when no_data_found then
     null;
    when too_many_rows then
     null;
   when others then
     if sqlcode = -54 then
        raise_application_error(-20000,
        'Registro bloqueado por otro usuario');
     end if;
     If sqlcode <= -20000 then
        raise;
     else
       raise_application_error(-20000,'Act.Operaciones '||sqlerrm);
     End if;
END;
/* Proceso que actualiza el monto aplicado del limite */
PROCEDURE PR_ACT_LIN_APLICADO
 (P_NRO_LINEA IN PR_CTA_PRESTAMOS.NRO_LINEA%TYPE
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 )
 IS
v_existe number(01);
BEGIN
   select 1 into v_existe
     from pr_lineas
    where nro_linea = p_nro_linea
    for update nowait;
   update pr_lineas
      set mto_aplicado = nvl(mto_aplicado,0) + p_monto
    where nro_linea = p_nro_linea;

exception
   when others then
     if sqlcode = -54 then
        raise_application_error(-20000,
        'Registro de linea '||p_nro_linea||' bloqueado por otro usuario');
     end if;
     If sqlcode <= -20000 then
       raise;
     else
       raise_application_error(-20000,'Act.Linea '||sqlerrm);
     End if;
END;

PROCEDURE PR_ACT_GAR_APLICADO
 (P_NRO_GARANTIA IN PR_CTA_GARANTIAS.NRO_GARANTIA%TYPE
 ,P_MON_PRESTAMO IN PR_CTA_PRESTAMOS.COD_MONEDA%TYPE
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 )
 IS
v_cod_moneda pr_garantias.cod_moneda%type;
v_cod_mon_tasacion pr_garantias.cod_mon_tasacion%type;
v_valor pr_garantias.valor%type;
v_val_tasacion pr_garantias.val_tasacion%type;
v_monto pr_garantias.mto_aplicado%type;
BEGIN
   v_monto := p_monto;
   select cod_moneda, nvl(valor,0), cod_mon_tasacion, nvl(val_tasacion,0)
     into v_cod_moneda, v_valor, v_cod_mon_tasacion, v_val_tasacion
     from pr_garantias
    where nro_garantia = p_nro_garantia
    for update nowait;
   --- Actualizo en la moneda de la garantia el monto aplicado
   v_monto := PAG_GEN.FU_CON_MON_A_MONEDA(p_mon_prestamo, v_cod_moneda, p_monto);
   update pr_garantias
      set mto_aplicado = nvl(mto_aplicado,0) + v_monto
    where nro_garantia = p_nro_garantia;
exception
   when no_data_found then
     --- Existen garantias asociadas a personas
     null;
   when others then
     if sqlcode = -54 then
        raise_application_error(-20000,
        'Registro de garantia '||p_nro_garantia||' bloqueado por otro usuario');
     end if;
     raise_application_error(-20000,'Act.Garantia '||sqlerrm);
END;
/* Proceso que act. el monto aplicado de tipos de garantia por limite */
PROCEDURE PR_ACT_TIP_LIMITE
 (P_NRO_LINEA IN PR_LINEAS.NRO_LINEA%TYPE
 ,P_COD_GARANTIA IN PR_CTA_GARANTIAS.COD_GARANTIA%TYPE
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 )
 IS
v_existe number(01);
BEGIN
   select 1 into v_existe
     from pr_lin_tip_garantias
    where nro_linea    = p_nro_linea
      and cod_garantia = p_cod_garantia
    for update nowait;
   update pr_lin_tip_garantias
      set mto_aplicado = nvl(mto_aplicado,0) + p_monto
    where nro_linea    = p_nro_linea
      and cod_garantia = p_cod_garantia;
exception
   when no_data_found then
     null;
   when others then
     if sqlcode = -54 then
        raise_application_error(-20000,
        'Registro bloqueado por otro usuario');
     end if;
     If sqlcode <= -20000 then
        raise;
     else
       raise_application_error(-20000,'Act.Limite '||sqlerrm);
     End if;
END;
/*Obtener datos de la garantía*/
PROCEDURE PR_OBT_DAT_GARANTIA
 (P_NRO_GARANTIA IN PR_GARANTIAS.NRO_GARANTIA%TYPE,
 P_MTO_APLICADO  IN OUT PR_GARANTIAS.MTO_APLICADO%TYPE,
 P_COD_MONEDA    IN OUT PR_GARANTIAS.COD_MONEDA%TYPE,
 P_TIPO          IN OUT PR_GARANTIAS.TIPO%TYPE,
 P_ESTADO        IN OUT PR_GARANTIAS.ESTADO%TYPE
 )
 IS
BEGIN
   select nvl(mto_aplicado,0), cod_moneda, tipo, estado
     into p_mto_aplicado, p_cod_moneda, p_tipo, p_estado
     from pr_garantias
    where nro_garantia = p_nro_garantia;
exception
   when no_data_found then
      raise_application_error(-20001, 'Garantia no registrada '||p_nro_garantia);
   when others then
      If sqlcode <= -20000 then
        raise;
      else
        raise_application_error(-20001,'Rec.Dat.Garantia '||sqlerrm);
      End if;
END;

/*Obtener montos computable y utilizado de la garantía para, posteriormente, poder calcular el saldo*/
PROCEDURE PR_OBT_GAR_MONTOS
(p_nro_garantia in pr_garantias.nro_garantia%type
,p_mto_utilizado out pr_garantias.mto_aplicado%type
,p_mto_computable out pr_garantias.mto_aplicado%type)
IS
begin
  --en la moneda de la garantía
  p_mto_computable := pap_gar.FU_OBT_VAL_COMPUTABLE(p_nro_garantia);
  --el mto utilizado de una garantía se determina por tipo de implementación 01/11/2005 VC
  select sum(pag_gen.fu_con_mon_a_moneda(p.cod_mon_ope, p.cod_moneda, NVL(MTO_APLICADO,0)))
      into p_mto_utilizado
      from gv_cta_garantias p
     where nro_garantia = p_nro_garantia
       and nro_cuenta is not null;
exception
  when no_data_found then
    raise_application_error(-20010,'Garantía no registrada '||p_nro_garantia);
  when others then
    if sqlcode <= -20000 then
      raise;
    else
      raise_application_error(-20010,'Recup.Garantía '||p_nro_garantia||'.'||sqlerrm);
    end if;
end;

/*Obtener monto de operaciones q cubre la garantía para, posteriormente, poder calcular el saldo*/
/*Esto es por tipo de implementación*/
FUNCTION FU_OBT_MTO_OPE_GARANTIA
 (P_NRO_GARANTIA IN PR_GARANTIAS.NRO_GARANTIA%TYPE
 )
 RETURN NUMBER IS
v_monto pr_garantias.mto_aplicado%type;
BEGIN
  --en la moneda de la garantía
   select nvl(sum(decode(cod_moneda,cod_mon_ope, nvl(mto_aplicado,0)/*nvl(sal_capital,0)+nvl(sal_interes,0)*/,
            pag_gen.FU_CON_MON_A_MONEDA(cod_mon_ope,cod_moneda, nvl(mto_aplicado,0)/*nvl(sal_capital,0)+nvl(sal_interes,0)*/))),0) monto
     into v_monto
     from gv_cta_garantias
    where nro_garantia = p_nro_garantia;
    return v_monto;
EXCEPTION
   when others then
      If sqlcode <= -20000 then
        raise;
      else
        raise_application_error(-20001,'Rec.Mto.Ope. Garantia '||sqlerrm);
      End if;
END;

/* Actualizar el bloqueo de cash con el mayor vto. de préstamo o solicitud,
bloquear saldos, estados, generar movimientos.
Por confirmación, y por eliminación de garantía o cancelación de préstamo */
PROCEDURE PR_PRO_GAR_CASH
 (P_NRO_GARANTIA   IN PR_GARANTIAS.NRO_GARANTIA%TYPE,
 p_nro_cuenta      in PR_cta_prestamos.NRO_cuenta%TYPE,
 p_nro_solicitud   in PR_solicitudes.NRO_solicitud%TYPE,
 p_fec_vencimiento in pr_cta_prestamos.fec_vencimiento%type,
 p_cod_modulo      in PR_cta_prestamos.cod_modulo%TYPE,
 p_cod_modalidad   in PR_cta_prestamos.cod_modalidad%TYPE,
 p_cod_oficina     in PR_cta_prestamos.cod_oficina%TYPE,
 p_cod_moneda      in PR_cta_prestamos.cod_moneda%TYPE,
 p_mto_aplicado    in pr_sol_garantias.mto_aplicado%type,
 p_tipo            in varchar2 default 'C'
 )
is
 --cash incluídos en la garantía
 cursor cash is
   select ct.cod_modulo cod_mod_cuenta, ct.cod_modalidad cod_mad_cuenta, ct.cod_oficina cod_ofi_cuenta,
          ct.cod_moneda cod_mon_cuenta,ca.monto monto, ca.nro_cta_referencia nro_cta_referencia,
          ca.nro_documento
     from pr_gar_cash ca,
          ge_cuentas ct
    where ca.nro_garantia  = p_nro_garantia
      and ca.nro_cta_referencia = ct.nro_cuenta(+);

  v_nro_cuenta     pr_cta_prestamos.nro_cuenta%type;
  v_observacion    ge_bloqueos.observacion%type;
  v_cod_modalidad  ge_cuentas.cod_modalidad%type;
  v_fec_valor      ge_movimientos.fec_valor%type;
  v_hora           ge_movimientos.hora%type;
  r_gmovi          ge_movimientos%rowtype;
  v_cod_modulo     ge_movimientos.cod_modulo%type;
  r_gbloq          ge_bloqueos%rowtype;
--  v_existe         varchar2(1):='S';
  v_cot_mon_ori    ge_cotizaciones.val_conversion%type;
  v_cot_mon_des    ge_cotizaciones.val_conversion%type;
  v_mto_bloqueo    ge_bloqueos.monto%type;
  v_mto_bloqueado  ge_bloqueos.monto%type;
  v_nro_secuencia  ge_movimientos.nro_secuencia%type :=0;
  v_nvo_estado     ge_cuentas.estado%type;
  v_sal_disponible ge_cuentas.sal_contable%type;
  v_procesa        varchar2(01);
  v_transaccion    ge_movimientos.cod_transaccion%type;
  v_cantidad       number;
  v_vto_pres       pr_cta_prestamos.fec_vencimiento%type;
  v_vto_sol        pr_cta_prestamos.fec_vencimiento%type;
  v_lugar          varchar2(1000);
/*Obtener cuenta o solicitud de préstamo para asociar al bloqueo*/
procedure pl_obt_cta_bloqueo
is
begin
 --trae la cta préstamo o solicitud asociados a la garantía d mayor vencimiento
 Select max(nro_cuenta)
   into v_nro_cuenta
   from 
 ((select a.nro_cuenta
                     from pr_cuotas b, pr_cta_garantias a
                    where b.nro_cuenta = a.nro_cuenta
                      and nro_garantia = p_nro_garantia
                      and estado <> 'N'
                      and  ((p_tipo = 'R' 
                              and a.nro_cuenta != nvl(p_nro_cuenta, p_nro_solicitud) ) or
                            p_tipo != 'R')
                      and nro_cuota >0)
         union all
        (select to_char(a.nro_solicitud)
                     from pr_solicitudes b, pr_sol_garantias a
                    where b.nro_solicitud = a.nro_solicitud
                      and nro_garantia = p_nro_garantia
                      and  ((p_tipo = 'R' 
                              and a.nro_solicitud != nvl(p_nro_cuenta, p_nro_solicitud) ) or
                            p_tipo != 'R')
                      and estado IN ('S','L'))
         union all
         (select g.nro_cuenta
            from ta_cta_tarjetas t, ta_cta_garantias g
           where t.nro_cuenta = g.nro_cuenta
             and t.estado != 'C'
             and g.nro_garantia = p_nro_garantia
            and  ((p_tipo = 'R' 
                    and g.nro_cuenta != nvl(p_nro_cuenta, p_nro_solicitud) ) or
                  p_tipo != 'R')             
             and nvl(mto_aplicado,0) > 0)
         union all
         (select to_char(a.nro_solicitud)
             from ta_solicitudes b, ta_sol_garantias a
            where b.nro_solicitud = a.nro_solicitud
              and nro_garantia = p_nro_garantia
              and  ((p_tipo = 'R' 
                      and a.nro_solicitud != nvl(p_nro_cuenta, p_nro_solicitud) ) or
                    p_tipo != 'R')
              and COD_estado IN ('PAN'))
         union all
         (select g.nro_cuenta
            from CX_cta_exportaciones t, CX_cta_garantias g
           where t.nro_cuenta = g.nro_cuenta
             and t.estado not in ('C','G')
             and g.nro_garantia = p_nro_garantia
            and  ((p_tipo = 'R' 
                    and g.nro_cuenta != nvl(p_nro_cuenta, p_nro_solicitud) ) or
                  p_tipo != 'R')             
             and nvl(mto_aplicado,0) > 0
          )  
         union all
         (select g.nro_cuenta
            from CX_cta_importaciones t, CX_cta_garantias g
           where t.nro_cuenta = g.nro_cuenta
             and t.estado not in ('C','G')
             and g.nro_garantia = p_nro_garantia
            and  ((p_tipo = 'R' 
                    and g.nro_cuenta != nvl(p_nro_cuenta, p_nro_solicitud) ) or
                  p_tipo != 'R')             
             and nvl(mto_aplicado,0) > 0
          )
         union all
         (select g.nro_cuenta
            from CX_fianzas t, CX_cta_garantias g
           where t.nro_cuenta = g.nro_cuenta
             and t.estado not in ('C')
             and g.nro_garantia = p_nro_garantia
            and  ((p_tipo = 'R' 
                    and g.nro_cuenta != nvl(p_nro_cuenta, p_nro_solicitud) ) or
                  p_tipo != 'R')             
             and nvl(mto_aplicado,0) > 0
          )
         union all
          (select g.nro_cuenta
            from ov_cta_vencidas t, ov_cta_garantias g
           where t.nro_cuenta = g.nro_cuenta
             and t.estado != 'C'
             and g.nro_garantia = p_nro_garantia
            and  ((p_tipo = 'R'
                    and g.nro_cuenta != nvl(p_nro_cuenta, p_nro_solicitud) ) or
                  p_tipo != 'R')
             and nvl(mto_aplicado,0) > 0)
        );
exception
  when no_data_found then
    v_vto_pres   := null;
    v_vto_sol    := null;
    v_nro_cuenta := null;
  when others then
    raise_application_error(-20003,'Obt.Dat.bloq '||sqlerrm);
end;

/* Verificar si es una cuenta perteneciente a la entidad */
FUNCTION LF_VER_CTA_GESTION
RETURN NUMBER
 IS
v_cod_modalidad ge_cuentas.cod_modalidad%type;
BEGIN
   select cod_modalidad, cod_modulo
     into v_cod_modalidad, v_cod_modulo
     from pr_cas_tipos prc,
          pr_gar_cash prg
    where prg.nro_garantia = p_nro_garantia
      and prg.cod_cas_tipo = prc.cod_cas_tipo
      and rownum = 1;
   return v_cod_modalidad;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Tipo de Garantía '||p_nro_garantia||' no registrado');
END;

/* Insertar registro de bloqueos. */
PROCEDURE lp_ins_ge_bloqueos(rp_gbloq IN ge_bloqueos%ROWTYPE) IS
   v_nro_documento ge_bloqueos.nro_documento%TYPE;
BEGIN

   insert into ge_bloqueos
      (nro_cuenta, fec_inicio, nro_documento, cod_causa, monto, hor_inicio, fec_fin, tipo,
       observacion, tip_bloqueo)
   values
      (rp_gbloq.nro_cuenta, rp_gbloq.fec_inicio, rp_gbloq.nro_documento, rp_gbloq.cod_causa,
       rp_gbloq.monto, rp_gbloq.hor_inicio, rp_gbloq.fec_fin, rp_gbloq.tipo, rp_gbloq.observacion,
       r_gbloq.tip_bloqueo);
exception
   when dup_val_on_index then   
      select max(a.nro_documento) + 1
        into v_nro_documento
        from ge_bloqueos a
       where a.nro_cuenta = rp_gbloq.nro_cuenta
         and a.fec_inicio = rp_gbloq.fec_inicio;
   
      insert into ge_bloqueos
         (nro_cuenta, fec_inicio, nro_documento, cod_causa, monto, hor_inicio, fec_fin, tipo,
          observacion, tip_bloqueo)
      values
         (rp_gbloq.nro_cuenta, rp_gbloq.fec_inicio, v_nro_documento, rp_gbloq.cod_causa,
          rp_gbloq.monto, rp_gbloq.hor_inicio, rp_gbloq.fec_fin, rp_gbloq.tipo, rp_gbloq.observacion,
          r_gbloq.tip_bloqueo);   
END;

/*proceso principal*/
begin
  if p_cod_modulo = 6 then
    --préstamos
    v_lugar := 'préstamo';
  elsif p_cod_modulo = 5 then
    --tarjetas
    v_lugar := 'tarjeta';
  elsif p_cod_modulo = 8 then
     if p_cod_modalidad = 81 then
       v_lugar := 'CCI'; --carta de crédito de importación (comex)
    elsif p_cod_modalidad in (88,89) then
       v_lugar := 'Fianza'; --fianza local, extranjera (comex)
    end if;
  end if;
  
  --el tipo de operación indica si es una (C)onfirmación o (R)eversión
  --recuperar los prestamos y solicitudes asociados a la garantía
  pl_obt_cta_bloqueo;
  if v_nro_cuenta is null then
    --no existen operaciones asociadas a la garantía o la actual es la mayor
    --se actualiza con el préstamo o solicitud actual --se elimina si es reversión
    If p_tipo != 'R' then
      if p_nro_cuenta is not null then
         v_nro_cuenta := p_nro_cuenta;
         v_observacion := 'Bloqueo por utilización en  '||v_lugar||' '||v_nro_cuenta;
      elsif p_nro_solicitud is not null then
         v_nro_cuenta := p_nro_solicitud;
         v_observacion := 'Bloqueo por utilización en solicitud de '||v_lugar||' '||v_nro_cuenta;
      end if;
    End if;
  else  -- verificar si el nuevo vto es mayor q el existente
    if p_tipo = 'R' then --eliminación
       v_observacion := 'Desbloqueo por utilización en solicitud/'||v_lugar||' '||v_nro_cuenta;
    else-- x confirmación, verificar fechas
        if p_nro_cuenta is not null then
           v_nro_cuenta := p_nro_cuenta;
           v_observacion := 'Bloqueo por utilización en '||v_lugar||' '||v_nro_cuenta;
        elsif p_nro_solicitud is not null then
           v_nro_cuenta := p_nro_solicitud;
           v_observacion := 'Bloqueo por utilización en solicitud de '||v_lugar||' '||v_nro_cuenta;
        end if;
    end if;
  end if;

  --recuperar los cash de la garantía
  for reg in cash loop
    pag_cta.pr_obt_cuenta(reg.nro_cta_referencia);
    /* - actualizar ge_bloqueos con la mayor fecha de vencimiento
       -bloquear saldo de la cuenta de cash
       -generar mov. -x saldo bloqueado
       -cambio de estado o bloqueo (depend.modalidad)*/
    --Verificar si corresponde a cuenta de ahorros
    v_cod_modulo := reg.cod_mod_cuenta;
    v_cod_modalidad := reg.cod_mad_cuenta;--lf_ver_cta_gestion;
    
    If v_cod_modalidad is not null then
      v_fec_valor := pag_cal.fu_obt_fec_actual(p_cod_modulo);
      --obtener sgte seg. xq conflictúa con los mov anteriores, q se generar x reversión x ej.
      Select nvl(max(hora), to_char(sysdate,'hh24:mi:ss')) into v_hora
        from ge_movimientos
       where cod_usuario = user;
      ---
      v_hora          := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
      --Verificar si el cda ya tiene bloqueo x cash en otra operación
      --una garantía puede tener varios cash
      --si ya tiene solo se actualiza,sino se inserta/bloquea y demás
      --BBVADES-2651
      /*
      begin
        update ge_bloqueos
           set nro_documento = nvl(nvl(v_nro_cuenta,p_nro_cuenta), p_nro_solicitud),
               observacion   = v_observacion
         where nro_cuenta = reg.nro_cta_referencia
           and cod_causa = fug_obt_pardinamico('COD_CAU_BLO_GARAN',p_cod_modulo, p_cod_modalidad, p_cod_moneda,p_cod_oficina)
           and tip_bloqueo = 'A';
         --si no existe insertar el registro
         if sql%notfound then
            v_existe :='N';
         end if;
         --si es reversión, verificar si tiene otro bloqueo,sino eliminar
      exception
         when others then
           raise_application_error(-20004,'Actu-Bloqueo '||sqlerrm);
      end;
      */
      --no existe el bloqueo, generar
      --BBVADES-2651
      if /*v_existe = 'N' and*/ p_tipo = 'C' then--confirmación operación
        --Convertir el monto a moneda de la cuenta en la cotizacion actual
        pag_gen.pr_con_mon_a_moneda(p_cod_moneda, reg.cod_mon_cuenta,
            nvl(p_mto_aplicado,0), v_mto_bloqueo, v_cot_mon_ori, v_cot_mon_des);
        v_nro_secuencia :=  nvl(v_nro_secuencia, 0) + 1;
        --Insertar ge_bloqueos
        r_gbloq.nro_cuenta    := reg.nro_cta_referencia;
        r_gbloq.fec_inicio    := v_fec_valor;
        --BBVADES-2651
        r_gbloq.nro_documento := reg.nro_documento;--v_nro_cuenta;--solictud o préstamo
        r_gbloq.cod_causa     := fug_obt_pardinamico('COD_CAU_BLO_GARAN',
                                 p_cod_modulo, p_cod_modalidad, p_cod_moneda,
                                 p_cod_oficina);
        r_gbloq.hor_inicio    := v_hora;
        r_gbloq.fec_fin       := null;
        r_gbloq.tipo          := 'S'; --- Bloqueo de saldo
        r_gbloq.tip_bloqueo   := 'A';
        r_gbloq.monto         := reg.monto;
        r_gbloq.observacion   := v_observacion;
        lp_ins_ge_bloqueos(r_gbloq);
        --- Actualizar saldo bloqueado
        /*tanto para cda como para vista se toma el monto de pr_gar_cash para bloquear y desbloquear,
        en el caso de cda sería el capital total de la cta, y para vista sería el ingresado x el usuario */
        v_mto_bloqueo :=reg.monto;--monto de la garantía
        If v_cod_modalidad in (31, 41) then
        --Determino si la cuenta es combinada y se asigna la transaccion correspondiente.          
           if pag_cta.g_ctas.cta_combinada = 'S' then
              v_transaccion := 2605;
           else
              v_transaccion := 2604;
           end if;
        elsif v_cod_modalidad in (33,34,35,36) then
          v_transaccion := 603;
        end if;

        --Verificar si se puede realizar el bloqueo
        pag_cta.pr_ver_operacion(reg.nro_cta_referencia,
                                 950,--cod_tra_padre
                                 v_cod_modulo,
                                 v_cod_modalidad,
                                 'C',
                                 reg.cod_mon_cuenta,
                                 v_mto_bloqueo,
                                 p_cod_oficina,
                                 -- out
                                 pag_cta.g_ctas.cod_modulo,
                                 pag_cta.g_ctas.cod_modalidad,
                                 v_nvo_estado,
                                 v_sal_disponible,
                                 v_procesa,
                                 v_transaccion); --cod_transaccion
          if pag_cta.g_cod_error <> 0 or v_procesa = 'N' then
             raise_application_error(-20000,pag_cta.FU_OBT_MSJ_ERROR||' Monto: '||v_mto_bloqueo);
          end if;
           
          pag_cta.PR_ACT_SAL_CTA(reg.nro_cta_referencia, v_cod_modalidad, 'C',
                                v_fec_valor, v_hora, null, null, v_mto_bloqueo, 'N');

        --- Insertar movimiento de saldo bloqueado
        r_gmovi.cod_usuario     := user;
        r_gmovi.hora            := v_hora;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.cod_modulo      := reg.cod_mod_cuenta;
        r_gmovi.cod_modalidad   := reg.cod_mad_cuenta;
        r_gmovi.cod_oficina     := reg.cod_ofi_cuenta;
        r_gmovi.nro_cuenta      := reg.nro_cta_referencia;
        r_gmovi.cod_moneda      := reg.cod_mon_cuenta;
        r_gmovi.fec_valor       := v_fec_valor;
        r_gmovi.fecha           := v_fec_valor;
        r_gmovi.cod_tra_padre   := 950; --- Garantías de préstamos
        r_gmovi.cod_transaccion := v_transaccion; -- Saldo bloqueado 603/1604
        r_gmovi.monto           := v_mto_bloqueo;
        r_gmovi.estado          := 'N';
        r_gmovi.cod_ofi_origen  := p_cod_oficina;
        r_gmovi.reversado       := 'N';
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.protegido       := 'N';
        r_gmovi.cod_mod_padre   := p_cod_modulo;--6;
        r_gmovi.cod_mad_padre   := p_cod_modalidad;
        r_gmovi.nro_documento   := v_nro_cuenta;
        r_gmovi.cod_causa       := r_gbloq.cod_causa;
        if p_cod_modulo = 8 then
           r_gmovi.concepto     := 'Bloqueo x garantia '||v_lugar;
        else
           r_gmovi.concepto     := 'Bloqueo x garantia solic/'||v_lugar;
        end if;
        pag_gen.pr_ins_ge_movimiento(r_gmovi);
        --- Actualizar estado de la cuenta
        If v_cod_modalidad in (31,41) then
           pag_cta.PR_ACT_EST_CTA(reg.nro_cta_referencia, v_cod_modalidad, 'S', v_fec_valor);
           --- Generar movimiento por cambio de estado
           v_nro_secuencia :=  nvl(v_nro_secuencia,0) + 1;
           r_gmovi.cod_usuario     := user;
           r_gmovi.hora            := v_hora;
           r_gmovi.nro_secuencia   := v_nro_secuencia;
           r_gmovi.cod_modulo      := reg.cod_mod_cuenta;
           r_gmovi.cod_modalidad   := reg.cod_mad_cuenta;
           r_gmovi.cod_oficina     := reg.cod_ofi_cuenta;
           r_gmovi.nro_cuenta      := reg.nro_cta_referencia;
           r_gmovi.cod_moneda      := reg.cod_mon_cuenta;
           r_gmovi.fec_valor       := v_fec_valor;
           r_gmovi.fecha           := v_fec_valor;
           r_gmovi.cod_tra_padre   := 950; --- Garantías de préstamos
           r_gmovi.cod_transaccion := 409; --- Estado bloqueo de saldos
           r_gmovi.est_cuenta      := 'S';
           r_gmovi.estado          := 'N';
           r_gmovi.cod_ofi_origen  := p_cod_oficina;
           r_gmovi.reversado       := 'N';
           r_gmovi.emi_aviso       := 'N';
           r_gmovi.protegido       := 'N';
           r_gmovi.cod_mod_padre   := p_cod_modulo;--6;
           r_gmovi.cod_mad_padre   := p_cod_modalidad;
           r_gmovi.monto           := null;
           r_gmovi.nro_documento   := v_nro_cuenta;
           r_gmovi.cod_causa       := r_gbloq.cod_causa;
           pag_gen.pr_ins_ge_movimiento(r_gmovi);
        elsif v_cod_modalidad in (33,34,35,36) then
           --actualizar campo bloqueado a SI
           pag_cta.PR_ACT_CTA_BLOQUEO(reg.nro_cta_referencia,'S');
        End if;--modalidad

      elsif /*v_existe <> 'N' and*/ p_tipo <> 'C' and v_nro_cuenta is null then --existe el bloqueo, es eliminación o cancelación
        -- Se cancela o elimina y es la última 
        -- cancelación de préstamo o eliminación de garantía
        If p_nro_cuenta is not null then
           v_nro_cuenta := p_nro_cuenta;
        Else
           v_nro_cuenta := p_nro_solicitud;
        End if;
        v_mto_bloqueado := reg.monto;
        v_nro_secuencia :=  nvl(v_nro_secuencia,0) + 1;
        --Determino la transaccion de la cuenta para la baja
        if v_cod_modalidad in (31, 41) then
           --Determino si la cuenta es combinada y se le asigna la transaccion correspondiente de cancelacion.
           if pag_cta.g_ctas.cta_combinada = 'S' then
              v_transaccion := 2508;
           else
              v_transaccion := 2507;               
           end if;
        elsif v_cod_modalidad in (33, 61) then
           --Determino si el certificado de ahorro se encuentra vencido y se le asigna la transaccion correspondiente de cancelacion.
           if pag_cta.g_ctas.est_certificado = 'V' then                 
              v_transaccion := 2508;
           else
              v_transaccion := 2507;
           end if;
        end if;        
        --x ahora elimina si la propuesta original se desasocia de la garantia
        --ver si se debe atar a otra si tiene o verificar si tiene otro asociado
        --Eliminar ge_bloqueos, solo si no hay operaciones asociadas
        if v_nro_cuenta = nvl(p_nro_cuenta,'X') or v_nro_cuenta = nvl(to_char(p_nro_solicitud),'X') then
           --Actualizar saldo bloqueado
           if nvl(v_mto_bloqueado,0) > 0 then            
              --Verificar si se puede realizar el desbloqueo
              pag_cta.pr_ver_operacion(reg.nro_cta_referencia,
                                       950,--cod_tra_padre
                                       v_cod_modulo,
                                       v_cod_modalidad,
                                       'D',
                                       reg.cod_mon_cuenta,
                                       v_mto_bloqueado,
                                       p_cod_oficina,
                                       -- out
                                       pag_cta.g_ctas.cod_modulo,
                                       pag_cta.g_ctas.cod_modalidad,
                                       v_nvo_estado,
                                       v_sal_disponible,
                                       v_procesa,
                                       v_transaccion);

            if pag_cta.g_cod_error <> 0 or v_procesa = 'N' then
               raise_application_error(-20000,pag_cta.FU_OBT_MSJ_ERROR);
            end if;
            --actualizar el saldo
            pag_cta.PR_ACT_SAL_CTA(reg.nro_cta_referencia, v_cod_modalidad, 'D',
                            v_fec_valor, v_hora, null, null, v_mto_bloqueado, 'N');
          End if;
          --si es igual al parámetro significa q no encontó oper. asociadas, si enoncontó ya actualizó arriba
          delete ge_bloqueos
           where nro_cuenta = reg.nro_cta_referencia
             and cod_causa = fug_obt_pardinamico('COD_CAU_BLO_GARAN',p_cod_modulo, p_cod_modalidad, p_cod_moneda,p_cod_oficina)
             and tip_bloqueo = 'A'
             and nro_documento = reg.nro_documento;
             --and fec_inicio = v_fec_valor;

          --- Insertar movimiento de saldo desbloqueado
          r_gmovi.cod_usuario     := user;
          r_gmovi.hora            := v_hora;
          r_gmovi.nro_secuencia   := v_nro_secuencia;
          r_gmovi.cod_modulo      := reg.cod_mod_cuenta;
          r_gmovi.cod_modalidad   := reg.cod_mad_cuenta;
          r_gmovi.cod_oficina     := reg.cod_ofi_cuenta;
          r_gmovi.nro_cuenta      := reg.nro_cta_referencia;
          r_gmovi.cod_moneda      := reg.cod_mon_cuenta;
          r_gmovi.fec_valor       := v_fec_valor;
          r_gmovi.fecha           := v_fec_valor;
          r_gmovi.cod_tra_padre   := 950; --- Garantías de préstamos
          r_gmovi.cod_transaccion := v_transaccion; --- Saldo bloqueado
          r_gmovi.estado          := 'N';
          r_gmovi.cod_ofi_origen  := p_cod_oficina;
          r_gmovi.reversado       := 'N';
          r_gmovi.emi_aviso       := 'N';
          r_gmovi.protegido       := 'N';
          r_gmovi.cod_mod_padre   := p_cod_modulo;--6;
          r_gmovi.cod_mad_padre   := p_cod_modalidad;
          --If v_cod_modalidad in (31,41) then
          r_gmovi.monto           := nvl(v_mto_bloqueado,0);
          r_gmovi.nro_documento   := v_nro_cuenta;
          -- AP 1520 - Guardar causal en mov. de desbloqueo
          r_gmovi.cod_causa       := fug_obt_pardinamico('COD_CAU_BLO_GARAN',
                                     p_cod_modulo, p_cod_modalidad, p_cod_moneda,
                                     p_cod_oficina);
          if p_cod_modulo = 8 then
             r_gmovi.concepto     := 'Desbloqueo x garant. '||v_lugar;
          else
             r_gmovi.concepto     := 'Desbloqueo x garant.solic/'||v_lugar;
          end if;
          pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
          --- Verificar si posee aun bloqueo
          begin
              select count(*) into v_cantidad
                from ge_bloqueos
               where nro_cuenta = reg.nro_cta_referencia;
           exception
              when no_data_found then
                   v_cantidad := 0;
           end;
           if v_cantidad = 0 then
              If v_cod_modalidad in (33,34,35,36) then
                 --actualizar campo bloqueado a NO
                 pag_cta.PR_ACT_CTA_BLOQUEO(reg.nro_cta_referencia,'N');
              else
                 --- Actualizar estado de la cuenta
                 pag_cta.PR_ACT_EST_CTA(reg.nro_cta_referencia, v_cod_modalidad, 'N', v_fec_valor);
                 --- Generar movimiento por cambio de estado
                 v_nro_secuencia :=  nvl(v_nro_secuencia,0) + 1;
                 r_gmovi.cod_usuario     := user;
                 r_gmovi.hora            := v_hora;
                 r_gmovi.nro_secuencia   := v_nro_secuencia;
                 r_gmovi.cod_modulo      := reg.cod_mod_cuenta;
                 r_gmovi.cod_modalidad   := reg.cod_mad_cuenta;
                 r_gmovi.cod_oficina     := reg.cod_ofi_cuenta;
                 r_gmovi.nro_cuenta      := reg.nro_cta_referencia;
                 r_gmovi.cod_moneda      := reg.cod_mon_cuenta;
                 r_gmovi.fec_valor       := v_fec_valor;
                 r_gmovi.fecha           := v_fec_valor;
                 r_gmovi.cod_tra_padre   := 950; --- Garantías de préstamos
                 r_gmovi.cod_transaccion := 415; --- Estado bloqueo de saldos
                 r_gmovi.est_cuenta      := 'N';
                 r_gmovi.estado          := 'N';
                 r_gmovi.cod_ofi_origen  := p_cod_oficina;
                 r_gmovi.reversado       := 'N';
                 r_gmovi.emi_aviso       := 'N';
                 r_gmovi.protegido       := 'N';
                 r_gmovi.cod_mod_padre   := p_cod_modulo;--6;
                 r_gmovi.cod_mad_padre   := p_cod_modalidad;
                 r_gmovi.monto           := null;
                 r_gmovi.nro_documento   := v_nro_cuenta;
                 r_gmovi.cod_causa       := fug_obt_pardinamico('COD_CAU_BLO_GARAN',
                                            p_cod_modulo, p_cod_modalidad, p_cod_moneda,
                                            p_cod_oficina);
                 pag_gen.pr_ins_ge_movimiento(r_gmovi);
              end if;
           end if;--si hay bloqueos
        end if; --si es última operación de la garantía
        --bbvades-2651
        v_nro_cuenta := null;
      end if;
    end if;--si modalidad
  end loop;
exception
  when others then
    if sqlcode <= -20000 then
      raise;
    else
      raise_application_error(-20005,'Actu-Bloqueo '||sqlerrm);
    end if;
end;

/* Verificar la aplicacion de una operacion a una garantia */
procedure PR_VER_APL_GARANTIA(
  p_cod_garantia   in     pr_garantias.cod_garantia%type,
  p_nro_garantia   in     pr_garantias.nro_garantia%type,
  p_nro_cuenta     in     varchar2,
  p_cod_moneda     in     pr_garantias.cod_moneda%type,
  p_mto_aplicar    in     number,
  p_mto_computable in out number,
  p_mto_cubierto   in out number,
  p_msj_error      in out varchar2,
  p_nro_linea      in     number default null)
 is
  v_valgar         pr_garantias.valor%type;
  v_valtas         pr_garantias.val_tasacion%type;
  v_porcbcp        pr_gar_tipos.por_bco_central%type;
  v_mto_utilizado  pr_sol_garantias.mto_aplicado%type;
  v_cod_mon_gar    ba_monedas.cod_moneda%type;
  v_gar_saldo      pr_sol_garantias.mto_aplicado%type;
  v_es_computable  pr_gar_tipos.computable%type;
  p_cuentas        varchar2(2000);
  v_estado         pr_garantias.estado%type;
  v_fec_incripcion date;
begin
    -- tomo el parametro msj_error que trae las cuentas renovadas
    p_cuentas   := p_msj_error;
    p_msj_error := null;
    If p_cod_garantia > 2 then
      if fug_obt_tip_implementacion = 3 then
        -- Toma en cuenta saldo de capital + interés
        If p_nro_linea is null then
          select sum(pag_gen.fu_con_mon_a_moneda(p.cod_mon_ope, p.cod_moneda, NVL(MTO_APLICADO,0)/*nvl(sal_capital,0)+nvl(sal_interes,0)*/))
            into v_mto_utilizado
            from gv_cta_garantias p
           where nro_garantia = p_nro_garantia
             and cod_garantia = p_cod_garantia
             and nro_cuenta is not null
             and nro_cuenta <> p_nro_cuenta;
        else
          select sum(pag_gen.fu_con_mon_a_moneda(p.cod_mon_ope, p.cod_moneda, NVL(MTO_APLICADO,0)/*nvl(sal_capital,0)+nvl(sal_interes,0)*/))
            into v_mto_utilizado
            from gv_cta_garantias p
           where nro_garantia = p_nro_garantia
             and cod_garantia = p_cod_garantia
             and nro_cuenta is not null
             and nvl(nro_linea,9999999) <> p_nro_linea;
        End if;
      else
        -- toma el monto aplicado
        If p_nro_linea is null then
          select sum(pag_gen.fu_con_mon_a_moneda(p.cod_mon_ope, p.cod_moneda, NVL(MTO_APLICADO,0)))
            into v_mto_utilizado
            from gv_cta_garantias p
           where nro_garantia = p_nro_garantia
             and cod_garantia = p_cod_garantia
             and nro_cuenta is not null
             and nro_cuenta <> p_nro_cuenta
             and instr(','||p_cuentas||',',','||p.nro_cuenta||',') = 0; -- no tomar los renovados
        else
          select sum(pag_gen.fu_con_mon_a_moneda(p.cod_mon_ope, p.cod_moneda, NVL(MTO_APLICADO,0)))
            into v_mto_utilizado
            from gv_cta_garantias p
           where nro_garantia = p_nro_garantia
             and cod_garantia = p_cod_garantia
             and nro_cuenta is not null
             and nvl(nro_linea,9999999) <> p_nro_linea
             and instr(','||p_cuentas||',',','||p.nro_cuenta||',') = 0; -- no tomar los renovados
        End if;
      end if;
       begin
        select pg.cod_moneda, pg.valor, pg.val_tasacion, pgt.por_bco_central, pgt.computable , pg.estado
          into v_cod_mon_gar, v_valgar, v_valtas       , v_porcbcp          , v_es_computable, v_estado
          from pr_gar_tipos pgt, pr_garantias pg
          where nro_garantia     = p_nro_garantia
            and pgt.cod_garantia = pg.cod_garantia;
      exception
        when no_data_found then
          p_msj_error := 'Garantia '||p_nro_garantia||' no registrada';
      end;
      if p_msj_error is null then
          -- obtener el total de garantías usadas
          If p_cod_garantia in (3,4,6,10,12) then
              --> Solo computa si el estado es confirmado y tiene fecha de Inscripción.-
              Begin
                  Select fec_inscripcion 
                    into v_fec_incripcion
                  From (Select a.fec_inscripcion
                        From pr_gar_hipotecarias a
                        where a.nro_garantia = p_nro_garantia
                        union 
                        Select a.fec_inscripcion
                        From pr_gar_vehiculos a
                        where a.nro_garantia = p_nro_garantia
                        union
                        Select a.fec_inscripcion
                        From pr_gar_warrants a
                        where a.nro_garantia = p_nro_garantia);
              Exception
                   When Others Then
                        Raise_application_error(-20000,'Error Al buscar Fecha de Inscripcion de la Garantia N° '||p_nro_garantia||' - '||sqlerrm);
              End;
          End IF;
          p_mto_cubierto   := nvl(v_mto_utilizado,0);
          p_mto_computable := pap_gar.FU_OBT_VAL_COMPUTABLE(p_nro_garantia);
          -- Para el cálculo de Saldo de la Garantía ya no se tendrá en cuenta el valor computable --CROMG-51- Mejora de Garantías
          /*if v_es_computable = 'S' and (v_estado = 'C' and v_fec_incripcion is not null) then
             v_gar_saldo      := nvl(p_mto_computable,0) - nvl(v_mto_utilizado,0);
          else*/
             v_gar_saldo      := nvl(v_valgar,0) - nvl(v_mto_utilizado,0);
          --end if;
          --verificar monedas
          if v_cod_mon_gar <> p_cod_moneda then
             v_gar_saldo := pag_gen.FU_CON_MON_A_MONEDA(v_cod_mon_gar,p_cod_moneda,v_gar_saldo);
          end if;
          --
          if p_mto_aplicar > v_gar_saldo then -- BBVADES-2651 - Mejora de Garantías.
            if v_gar_saldo < 0 then
               p_msj_error := 'Saldo de garantía N°: '||p_nro_garantia||'. No cubre el Monto a Aplicar';
            end if;
          end if;
      end if;
    end if;--gar >2
exception
  when others then
    p_msj_error := 'Error pr_ver_apl_garantia '||sqlerrm;
end;

/* Actualizar el monto aplicado de las garantías de una operación */
procedure PR_ACT_APL_GARANTIA(
  p_nro_cuenta     in     varchar2,
  p_mto_aplicar    in     number,
  p_tipo           in     varchar2 default 'A',
  p_msj_error      in out varchar2)
is
--determinar prioridad d afectación de garantías
-- préstamos --
v_referencia varchar2(30);

CURSOR garantia is
   select mto_aplicado, t.rowid reg_garantia, 'pr_cta_garantias' referencia
     from pr_cta_garantias t, pr_gar_tipos g
    where t.cod_garantia = g.cod_garantia
    and t.nro_cuenta = p_nro_cuenta
 order by t.nro_cuenta, g.pri_aplicacion
   --for update of mto_aplicado nowait;
   for update nowait;

-- operaciones vencidas --
   CURSOR garantia_ov is
   select mto_aplicado, t.rowid reg_gar_ov, 'ov_cta_garantias' referencia
     from ov_cta_garantias t, pr_gar_tipos g
    where t.cod_garantia = g.cod_garantia
    and t.nro_cuenta = p_nro_cuenta
 order by t.nro_cuenta, g.pri_aplicacion
   --for update of mto_aplicado nowait;
   for update nowait;

v_mto_aplicado pr_cta_garantias.mto_aplicado%type;
v_resto        pr_cta_garantias.mto_aplicado%type;
BEGIN
  --actualizar el monto aplicado, la moneda es la misma q la operación
  v_mto_aplicado := p_mto_aplicar;
  for reg in garantia loop
     v_referencia := reg.referencia;
     --ir descontando en base al monto
     if p_tipo = 'D' then --desafectar
        if v_mto_aplicado >= reg.mto_aplicado then
           v_resto        := v_mto_aplicado - reg.mto_aplicado;
           v_mto_aplicado := reg.mto_aplicado;
        else
           v_resto := 0;
        end if;
        if v_mto_aplicado <> 0 then
           update pr_cta_garantias
              set mto_aplicado = nvl(mto_aplicado,0) - v_mto_aplicado
            where rowid = reg.reg_garantia;
            --where current of garantia;
        end if;
        if v_resto = 0 then
           return;
        else
           v_mto_aplicado := v_resto;
        end if;
     end if;
  end loop;
  ------------------------
  -- operaciones vencidas
    for reg in garantia_ov loop
      v_referencia := reg.referencia;
     --ir descontando en base al monto
     if p_tipo = 'D' then --desafectar
        if v_mto_aplicado >= reg.mto_aplicado then
           v_resto        := v_mto_aplicado - reg.mto_aplicado;
           v_mto_aplicado := reg.mto_aplicado;
        else
           v_resto := 0;
        end if;
        if v_mto_aplicado <> 0 then
           update ov_cta_garantias
              set mto_aplicado = nvl(mto_aplicado,0) - v_mto_aplicado
            --where current of garantia_ov;
            where rowid = reg.reg_gar_ov;
        end if;
        if v_resto = 0 then
           return;
        else
           v_mto_aplicado := v_resto;
        end if;
     end if;
  end loop;

exception
  when others then
    --ojo ver si cae x error o devuelve msje
    --raise_application_error(-20000,'Act.Apl.Garantia,cta '||p_nro_cuenta||sqlerrm);
    --p_msj_error := 'Error pr_ver_apl_garantia '||sqlerrm;
  -----
  -----
      if sqlcode = -54 then  -- registro bloqueado por otro usuario
         raise_application_error(-20000, v_referencia||' utilizado por otro Usuario. Verifique.');
      else
         raise_application_error(-20000,'Act.Apl.Garantia,cta '||p_nro_cuenta||sqlerrm);
         p_msj_error := 'Error pr_ver_apl_garantia '||sqlerrm;
      end if;
end;

/*Obtener cuenta o solicitud de operaciones relacionadas a la garantia */
FUNCTION FU_OBT_CTA_VIN_GARANTIAS (
  P_NRO_GARANTIA   IN PR_GARANTIAS.NRO_GARANTIA%type
 ,P_COD_GARANTIA IN PR_GARANTIAS.COD_GARANTIA%type)--DYDMR-10177, se agrega el parametro cod_garantia
  return varchar2
as
v_nro_cuenta varchar2(16) := null;
begin
 --trae la cta préstamo o solicitud asociados a la garantía d mayor vencimiento
 Select max(nro_cuenta)
   into v_nro_cuenta
   from 
 ((select a.nro_cuenta
                     from pr_cuotas b, pr_cta_garantias a
                    where b.nro_cuenta = a.nro_cuenta
                      and nro_garantia = p_nro_garantia
                      and estado <> 'N'
                      and nro_cuota >0
                      and (p_cod_garantia is null or a.cod_garantia = p_cod_garantia))--DYDMR-10177
         union all
        (select to_char(a.nro_solicitud)
                     from pr_solicitudes b, pr_sol_garantias a
                    where b.nro_solicitud = a.nro_solicitud
                      and nro_garantia = p_nro_garantia
                      and estado IN ('S','L')
                      and (p_cod_garantia is null or a.cod_garantia = p_cod_garantia))--DYDMR-10177
         union all
         (select g.nro_cuenta
            from ta_cta_tarjetas t, ta_cta_garantias g
           where t.nro_cuenta = g.nro_cuenta
             and t.estado != 'C'
             and g.nro_garantia = p_nro_garantia
             and nvl(mto_aplicado,0) > 0
             and (p_cod_garantia is null or g.cod_garantia = p_cod_garantia))--DYDMR-10177
         union all
         (select to_char(a.nro_solicitud)
             from ta_solicitudes b, ta_sol_garantias a
            where b.nro_solicitud = a.nro_solicitud
              and nro_garantia = p_nro_garantia
              and COD_estado IN ('PAN')
              and (p_cod_garantia is null or a.cod_garantia = p_cod_garantia))--DYDMR-10177
         union all
         (select g.nro_cuenta
            from CX_cta_exportaciones t, CX_cta_garantias g
           where t.nro_cuenta = g.nro_cuenta
             and t.estado not in ('C','G')
             and g.nro_garantia = p_nro_garantia
             and nvl(mto_aplicado,0) > 0
             and (p_cod_garantia is null or g.cod_garantia = p_cod_garantia)--DYDMR-10177
          )  
         union all
         (select g.nro_cuenta
            from CX_cta_importaciones t, CX_cta_garantias g
           where t.nro_cuenta = g.nro_cuenta
             and t.estado not in ('C','G')
             and g.nro_garantia = p_nro_garantia
             and nvl(mto_aplicado,0) > 0
             and (p_cod_garantia is null or g.cod_garantia = p_cod_garantia)--DYDMR-10177
          )
         union all
         (select g.nro_cuenta
            from CX_fianzas t, CX_cta_garantias g
           where t.nro_cuenta = g.nro_cuenta
             and t.estado not in ('C')
             and g.nro_garantia = p_nro_garantia
             and nvl(mto_aplicado,0) > 0
             and (p_cod_garantia is null or g.cod_garantia = p_cod_garantia)--DYDMR-10177
          )
         union all
          (select g.nro_cuenta
            from ov_cta_vencidas t, ov_cta_garantias g
           where t.nro_cuenta = g.nro_cuenta
             and t.estado != 'C'
             and g.nro_garantia = p_nro_garantia
             and nvl(mto_aplicado,0) > 0
             and (p_cod_garantia is null or g.cod_garantia = p_cod_garantia))--DYDMR-10177
        );
        
        return v_nro_cuenta;
exception
  when no_data_found then
    v_nro_cuenta := null; 
    return v_nro_cuenta;   
  when others then
    v_nro_cuenta := null;
    return v_nro_cuenta;
end;

/* BBVADES-2651 - Actualizar la Fecha de Firma de Escribania en la tabla de Garantías Hipotecarias y Prenda */ 
PROCEDURE PR_ACT_FEC_FIR_ESCRIBANIA(P_NRO_GARANTIA      IN PR_GARANTIAS.NRO_GARANTIA%TYPE,
                                    P_FEC_FIR_ESCRITURA IN PR_GAR_HIPOTECARIAS.FEC_FIR_ESCRITURA%TYPE,
                                    P_NRO_FINCA         IN PR_GAR_HIPOTECARIAS.NRO_FINCA%TYPE,
                                    P_NRO_CONTRATO      IN PR_GAR_VEHICULOS.NRO_CONTRATO%TYPE) IS
   v_fec_inicio DATE;
   v_fec_actual DATE := pag_cal.fu_obt_fec_actual(6);
BEGIN

   SELECT fec_inicio
     INTO v_fec_inicio
     FROM pr_garantias a
    WHERE a.nro_garantia = P_NRO_GARANTIA;

   IF P_FEC_FIR_ESCRITURA > v_fec_actual THEN
      raise_application_error(-20000, 'Fecha de Firma de Escritura no puede ser superior a la Fecha Actual.');
   ELSIF P_FEC_FIR_ESCRITURA < v_fec_inicio THEN
      raise_application_error(-20000, 'Fecha de Firma de Escritura no puede ser inferior a la Fecha de la Escritura.');
   END IF;

   IF P_NRO_FINCA IS NOT NULL THEN
     UPDATE PR_GAR_HIPOTECARIAS
        SET FEC_FIR_ESCRITURA = P_FEC_FIR_ESCRITURA
      WHERE NRO_GARANTIA = P_NRO_GARANTIA
        AND NRO_FINCA    = P_NRO_FINCA;
   ELSIF P_NRO_CONTRATO IS NOT NULL THEN
     UPDATE PR_GAR_VEHICULOS
        SET FEC_FIR_ESCRITURA = P_FEC_FIR_ESCRITURA
      WHERE NRO_GARANTIA = P_NRO_GARANTIA
        AND NRO_CONTRATO = P_NRO_CONTRATO;
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE = -54 THEN
         raise_application_error(-20000, 'Nro. Garantía ' || P_NRO_GARANTIA || ' bloqueado por otro usuario');
      END IF;
      IF SQLCODE <= -20000 THEN
         RAISE;
      ELSE
         raise_application_error(-20000, 'Act.Linea ' || SQLERRM);
      END IF;
END;

/*Actualizar la Fecha de Inscripción en la tabla de Garantías Hipotecarias, Prenda y Warrants*/
PROCEDURE PR_ACT_FEC_INSCRIPCION(P_NRO_GARANTIA    IN PR_GARANTIAS.NRO_GARANTIA%TYPE,
                                 P_FEC_INSCRIPCION IN PR_GAR_HIPOTECARIAS.FEC_INSCRIPCION%TYPE,
                                 P_NRO_FINCA       IN PR_GAR_HIPOTECARIAS.NRO_FINCA%TYPE,
                                 P_NRO_CONTRATO    IN PR_GAR_VEHICULOS.NRO_CONTRATO%TYPE,
                                 P_NRO_WARRANTS    IN PR_GAR_WARRANTS.NRO_WARRANTS%TYPE,
                                 P_NRO_CLAMERCA    IN PR_GAR_WARRANTS.CLA_MERCADERIA%TYPE) IS
   v_fec_actual DATE := pag_cal.fu_obt_fec_actual(6);
BEGIN
   IF P_FEC_INSCRIPCION > v_fec_actual THEN
      raise_application_error(-20000, 'La Fecha de Inscripción no puede ser superior a la Fecha Actual.');
   END IF;

   IF P_NRO_FINCA IS NOT NULL THEN
      UPDATE PR_GAR_HIPOTECARIAS
         SET FEC_INSCRIPCION = P_FEC_INSCRIPCION
       WHERE NRO_GARANTIA = P_NRO_GARANTIA
         AND NRO_FINCA    = P_NRO_FINCA;
   
   ELSIF P_NRO_CONTRATO IS NOT NULL THEN
      UPDATE PR_GAR_VEHICULOS
         SET FEC_INSCRIPCION = P_FEC_INSCRIPCION
       WHERE NRO_GARANTIA = P_NRO_GARANTIA
         AND NRO_CONTRATO = P_NRO_CONTRATO;
   
   ELSIF P_NRO_WARRANTS IS NOT NULL AND P_NRO_CLAMERCA IS NOT NULL THEN
      UPDATE PR_GAR_WARRANTS
         SET FEC_INSCRIPCION = P_FEC_INSCRIPCION
       WHERE NRO_GARANTIA = P_NRO_GARANTIA
         AND NRO_WARRANTS = P_NRO_WARRANTS
         AND CLA_MERCADERIA = P_NRO_CLAMERCA;
   
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE = -54 THEN
         raise_application_error(-20000, 'Nro. Garantía ' || P_NRO_GARANTIA || ' bloqueado por otro usuario');
      END IF;
      IF SQLCODE <= -20000 THEN
         RAISE;        
      ELSE
         raise_application_error(-20000, 'Act.Linea ' || SQLERRM);
      END IF;
END;
END PAP_GAR;
/
