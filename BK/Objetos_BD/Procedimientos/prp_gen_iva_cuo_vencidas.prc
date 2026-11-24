CREATE OR REPLACE PROCEDURE IT.PRP_GEN_IVA_CUO_VENCIDAS (
 P_PROCESO in VARCHAR2 default 'F')
IS

v_fec_anterior  date;
v_fec_hoy  date;
v_fec_fin  date;

-- Cursor de solicitudes desembolsadas en la fecha
Cursor c_cuotas is
 select p.nro_cuenta, p.cod_modulo, p.cod_modalidad, p.cod_oficina,
        p.cod_moneda, s.sal_interes, s.nro_cuota
   from pr_cuotas s, pr_cta_prestamos p
  where s.estado <> 'N'  --que no esté cancelada
    and s.sal_interes > 0 -- que tenga saldo de interes
    and s.fec_vencimiento > v_fec_anterior
    and s.fec_vencimiento <= v_fec_fin
    and p.nro_cuenta = s.nro_cuenta
    and not exists (select 1 from pr_sol_cargos car   --que no se haya cobrado Iva en el desembolso
                     where car.nro_solicitud = p.nro_solicitud
                       and car.cod_transaccion = 709) -- Iva s/interes
 union
select p.nro_cuenta, p.cod_modulo, p.cod_modalidad, p.cod_oficina,
       p.cod_moneda, (b.monto * -1) sal_interes, a.nro_cuota
  from pr_cuotas a, ge_movimientos b, pr_cta_prestamos p
 where a.nro_cuenta = b.nro_cuenta
   and a.fec_vencimiento >= b.fec_valor
   and a.fec_vencimiento < b.fecha --DYDMR-6186--Que sólo tome cuotas ya vencidas al momento de la reversión.
   -- En caso de reversiones historicas
   and b.fecha <> b.fec_valor
   and a.nro_cuota = b.nro_documento3
   and b.cod_tra_padre in (360,364)--DYDMR-3689--Se agrega TRX 364 para Cobro de préstamos por débito automático
   and b.cod_transaccion = 802
   and b.reversado = 'S'
   and a.nro_cuenta = p.nro_cuenta
   -- En caso de que se haya reversado el mismo día que tome el cursor anterior
   and not exists (select 1
                     from pr_cuotas ss, pr_cta_prestamos pp
                    where ss.estado <> 'N'  --que no esté cancelada
                      and ss.sal_interes > 0 -- que tenga saldo de interes
                      and ss.fec_vencimiento > v_fec_anterior
                      and ss.fec_vencimiento <=  v_fec_fin
                      and pp.nro_cuenta = ss.nro_cuenta
                      and ss.nro_cuenta = a.nro_cuenta
                      and ss.nro_cuota = a.nro_cuota)
   and not exists (select 1
                     from pr_sol_cargos car
                    where car.nro_solicitud = p.nro_solicitud
                      and car.cod_transaccion = 709)
   and P_PROCESO = 'F';
--*
v_fec_vigencia    date;
v_cod_mon_local   ge_movimientos.cod_moneda%type  := pag_gen.fu_obt_mon_local;
v_cotizacion      ge_movimientos.cotizacion%type;
v_cod_tasa        ge_movimientos.cod_tasa%type;
v_val_Tasa        ge_movimientos.val_tasa%type;
v_tip_Valor       ge_Tasas.Tip_Valor%type;
v_tipo            ge_Tasas.Tipo%type;
v_impuesto        number;
v_redondeo_ml     number(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, null, pag_gen.fu_obt_mon_local);
v_redondeo        number;
v_cod_ofi_origen  ba_usuarios.cod_oficina%type := FUG_OBT_OFI_USUARIO(USER);
v_usuario  ba_usuarios.cod_usuario%type;
v_can_user number;
-- CHEROGA ------------------------------
v_iva_divisor  number; -- IVA DIVISOR
v_iva_por_int  number; -- PORCION GRAVADA
v_iva_por_exe  number; -- PORCION EXENTA
v_mto_gravado   number;
-- CHEROGA ------------------------------
-- para asignacion de usuario
TYPE typ_usu_secuencia IS TABLE OF NUMBER INDEX BY VARCHAR2(50);
v_usu_secuencia typ_usu_secuencia;
  
TYPE t_usu_hor IS TABLE OF VARCHAR2(8) INDEX BY VARCHAR2(15);
v_usu_hora t_usu_hor;

-- Variables de registro
r_gmovi           ge_movimientos%rowtype;
--------------------------------------------------------------------------------------------
--  EMPIEZA EL PROCEDIMIENTO
--------------------------------------------------------------------------------------------
BEGIN
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 6; end;
  PAG_CAL.PR_OBT_DAT_CALENDAR(6);
  v_fec_hoy       := PAG_CAL.G_FEC_ACTUAL;
  
  v_iva_divisor := to_number(nvl(fug_obt_pardinamico('PRE_CHE_ROG_VAL_DIVISOR', 6, 668, null, null,null),'1'),'999G999D999999', 'NLS_NUMERIC_CHARACTERS='',.'''); 
  v_iva_por_int := to_number(nvl(fug_obt_pardinamico('PRE_CHE_ROG_POR_IVA_CAL', 6, 668, null, null,null),'1'),'999G999D999999', 'NLS_NUMERIC_CHARACTERS='',.'''); 
  v_iva_por_exe := to_number(nvl(fug_obt_pardinamico('PRE_CHE_ROG_POR_EXE_CAL', 6, 668, null, null,null),'1'),'999G999D999999', 'NLS_NUMERIC_CHARACTERS='',.'''); 
  --
   BEGIN
     SELECT COUNT(*)
       INTO v_can_user
       FROM ba_cod_referencias
       WHERE dominio     = 'USU_MOV_CIERRE'
         AND abreviatura = 'MOVCIERRE';
     EXCEPTION 
       WHEN OTHERS THEN 
         NULL;
   END;
  
  --Si la fecha siguiente habil corresponde al mismo mes asignar como fecha siguiente la actual
  --porque solo debe procesar fecha siguiente cuando esta cae en fin de mes.
  if p_proceso = 'I' then --- llamado desde un inicio de dia
     v_fec_anterior  := pag_cal.fu_obt_fec_ant_hab(v_fec_hoy,1);
     v_fec_fin := v_fec_hoy - 1;
     If to_char(v_fec_anterior,'mm') <> to_char(v_fec_hoy,'mm') then
        v_fec_anterior := last_day(v_fec_anterior);
     end if;
  else --- p_proceso = 'F' => llamado desde un cierre de dia
     v_fec_anterior := v_fec_hoy - 1;
     if v_fec_hoy = pag_cal.g_ult_dia_mes_habil then
        v_fec_fin := pag_cal.g_ult_dia_mes;
     else
        v_fec_fin := v_fec_hoy;
     end if;
  end if;

  --Recorrer cursor de cuotas vencidas
  For c in c_cuotas loop
    --- Obtener tasa de impuestos
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', c.cod_modulo, c.cod_modalidad, c.cod_moneda, c.cod_oficina);
    pag_gen.pr_obt_val_tasa(c.cod_modulo,c.cod_modalidad,
                            c.cod_oficina, c.nro_cuenta, c.cod_moneda,
                            0, 'N', v_cod_tasa, 709, --Transaccion
                            v_fec_hoy, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
    --- Calcular el iva
    IF nvl(fug_obt_pardinamico('COD_MOD_CHE_ROGA', c.cod_modulo,c.cod_modalidad),'N') = 'S' THEN
        v_mto_gravado := round((nvl(c.sal_interes, 0) / v_iva_divisor * v_iva_por_int) / 100, v_redondeo);
    ELSE
        v_mto_gravado := c.sal_interes;
    END IF;
    
    v_impuesto := round(nvl(v_mto_gravado,0) * (v_val_tasa / 100), v_redondeo);
      
    v_usuario := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE','USU_MOV_CIERRE',V_CAN_USER,'S_USU_MOVCIERRE'); 
    IF NOT v_usu_secuencia.EXISTS(v_usuario) THEN
       v_usu_secuencia(v_usuario) := 0;
       v_usu_hora(v_usuario)      := PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E');
    END IF; 
    IF v_usu_secuencia(v_usuario) >= 995 THEN
        v_usu_secuencia(v_usuario) := 1;
        v_usu_hora(v_usuario)      :=  PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E');
    ELSE
        -- Se incrementa la secuencia del usuario
        v_usu_secuencia(v_usuario) := v_usu_secuencia(v_usuario) + 1;
    END IF;

    r_gmovi.nro_secuencia      := v_usu_secuencia(v_usuario);
    r_gmovi.cod_usuario        := v_usuario;
    r_gmovi.hora               := v_usu_hora(v_usuario);
    r_gmovi.fecha              := v_fec_hoy;
    r_gmovi.cod_modulo         := c.cod_modulo;
    r_gmovi.cod_modalidad      := c.cod_modalidad;
    r_gmovi.cod_oficina        := c.cod_oficina;
    r_gmovi.nro_cuenta         := c.nro_cuenta;
    r_gmovi.cod_moneda         := c.cod_moneda;
    r_gmovi.est_cuenta         := null;
    r_gmovi.cod_tra_padre      := 391;  -- Cargos por Iva s/Interes vencido
    r_gmovi.cod_transaccion    := 710;  -- Iva s/Interes (lleva a cta.suspenso)
    r_gmovi.concepto           := 'Iva s/Interes';
    r_gmovi.monto              := v_impuesto;
    r_gmovi.nro_documento2     := c.sal_interes; --Se guarda el monto imponible para la Generacion del libro de iva
    if c.cod_moneda <> v_cod_mon_local then
       v_cotizacion               := pag_gen.fu_obt_cotizacion(c.cod_moneda, v_fec_hoy);
       r_gmovi.cotizacion         := v_cotizacion;
       r_gmovi.mto_equ_local      := round(trunc(v_impuesto,2)*v_cotizacion,v_redondeo_ml);
       r_gmovi.nro_documento3     := round(trunc(c.sal_interes,2)*v_cotizacion,v_redondeo_ml);
    else
       v_cotizacion               := null;
       r_gmovi.cotizacion         := null;
       r_gmovi.mto_equ_local      := null;
       r_gmovi.nro_documento3     := null;
    end if;
    r_gmovi.fec_valor          := v_fec_hoy;
    r_gmovi.emi_aviso          := 'S';
    r_gmovi.reversado          := 'N';
    r_gmovi.protegido          := 'N';
    r_gmovi.estado             := 'N';
    r_gmovi.cod_ofi_origen     := v_cod_ofi_origen;
    r_gmovi.cod_mod_padre      := c.cod_modulo;
    r_gmovi.cod_mad_padre      := c.cod_modalidad;
    r_gmovi.nro_documento      := c.nro_cuota;  --Nro.cuota para ser utlizado en el PAB_IVA
    r_gmovi.val_tasa           := v_val_tasa;
    pag_gen.pr_ins_ge_movimiento(r_gmovi);

    --Actualizar el monto imponible en Pr_cuotas
    Update pr_cuotas set mto_iva_imponible = v_mto_gravado
     where nro_cuenta = c.nro_cuenta
       and nro_cuota  = c.nro_cuota;

   IF nvl(fug_obt_pardinamico('COD_MOD_CHE_ROGA', c.cod_modulo,c.cod_modalidad),'N') = 'S' THEN

         r_gmovi.monto               := round( ((nvl(c.sal_interes,0) / v_iva_divisor * v_iva_por_exe/100)),v_redondeo);

         v_usu_secuencia(v_usuario)  := v_usu_secuencia(v_usuario) + 1;
         r_gmovi.nro_secuencia       := v_usu_secuencia(v_usuario);
         r_gmovi.emi_aviso           := 'S';
         r_gmovi.cotizacion          := v_cotizacion;
         r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,v_redondeo_ml);
         r_gmovi.concepto            := 'Interes exento';
         r_gmovi.cod_transaccion     := 1112;

         IF nvl(r_gmovi.monto,0) > 0 then
            pag_gen.pr_ins_ge_movimiento(r_gmovi); 
         END IF;
   END IF;
    
    --limpiar variables
    v_cod_tasa     := null;
    v_val_tasa     := null;
    v_fec_vigencia := null;
    v_tip_valor    := null;
    v_tipo         := null;
    ------   
  End loop;

Exception
  WHEN OTHERS THEN
     raise_application_error(-20000, 'Error al generar Iva s/Interes Vencido.  Error : '||sqlerrm);
END;
/
