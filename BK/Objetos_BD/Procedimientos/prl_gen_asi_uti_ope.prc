CREATE OR REPLACE PROCEDURE IT.prl_gen_asi_uti_ope
 IS

--- OBS: Ultimo Proceso del cierre de Cambios
--- Genera asientos de utilidad de cambios por operacion de cambios
   v_fec_actual     ge_calendarios.fec_actual%type;
   v_cod_mon_local  ba_monedas.cod_moneda%type;
   v_cod_ofi_trading  ge_movimientos.cod_oficina%type := fug_obt_pardinamico('LCA_COD_OFI_UTILIDAD');
   v_mto_resultado  lc_ope_futuras.monto%type;
   v_mensaje        varchar2(1000);
   v_cont           number := 0;

   ------------------------------------------------------------------
   -- Cursor de los registros del LC_SAL_DIARIOS.
   ------------------------------------------------------------------
   CURSOR C_MONEDA IS
    select fecha, hora, cod_usuario, monto, cod_moneda, mto_equ_local, cotizacion cot_ope,
           pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha) cot_bcp,
           round(pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha) * monto,0) mto_equ_bcp,
           cod_ofi_origen, cod_oficina, estado, reversado, nro_secuencia,
           a.cod_mod_padre, a.cod_mad_padre, a.cod_tra_padre, a.cod_modulo, a.cod_modalidad, a.cod_transaccion,
           concepto, b.cod_mad_hijo cod_mad_cambio, a.nro_documento, a.rowid fila,
           afe_ope_futura, a.cod_ref_cambio cod_tip_referencia, a.nro_documento2 nro_referencia
      from lc_tip_operaciones b, ge_movimientos a
     where a.cod_mod_padre = 7
       and a.cod_mad_padre in (71,72,73,74)
       and a.cod_moneda <> v_cod_mon_local
       and a.cod_tip_ope_cambio = b.cod_tip_operacion
       and a.nro_secuencia in (1,2,3,4)--DYDMR-7423 - Operaciones de Cambio con Ctas. Combinadas se registran en la secuencia 4.-
       and a.cod_transaccion not in  (760, 942) --BBVASOP-1314 No tomar 760: Limite Cambios, 942: Boleteo
       and a.reversado = 'N'
       and not(cod_tra_padre = 277 and cod_ref_cambio is null)
    union
    select b.fecha, b.hora, b.cod_usuario, nvl(b.monto,0) monto, b.cod_moneda, b.mto_equ_local, b.cotizacion cot_ope,
           pag_gen.FU_OBT_COTIZACION(b.cod_moneda,b.fecha) cot_bcp,
           round(pag_gen.FU_OBT_COTIZACION(b.cod_moneda,b.fecha) * b.monto,0) mto_equ_bcp,
           b.cod_ofi_origen, b.cod_oficina, b.estado, b.reversado, b.nro_secuencia,
           b.cod_mod_padre, b.cod_mad_padre, b.cod_tra_padre, b.cod_modulo, b.cod_modalidad, b.cod_transaccion,
           b.concepto,
           CASE WHEN b.monto >= 0 THEN 72
                WHEN b.monto < 0 then 71 end cod_mad_cambio,
           a.nro_documento, b.rowid fila, 'N' afe_ope_futura,
           CASE WHEN b.monto >= 0 THEN '31'
                WHEN b.monto <  0 THEN '17' end cod_tip_referencia, a.nro_documento2 nro_referencia
      from ge_movimientos b, ge_movimientos a
     where a.cod_mod_padre = 9
       and a.cod_tra_padre in (388,486)  -- TRANSF.HB
       and a.estado = 'N'
       and a.cod_transaccion = 503
       and a.monto <> 0
       and b.cod_mod_padre = 9
       and b.estado = 'N'
       and b.cod_transaccion = 602
       and b.fecha = a.fecha
       and b.cod_usuario = a.cod_usuario
       and b.hora = a.hora
       and b.nro_documento = a.nro_documento
       and b.cod_moneda <> a.cod_moneda
       and b.monto <> 0
       and b.cod_moneda <> v_cod_mon_local
       and ((a.reversado = 'N') OR (a.reversado = 'S' and a.fecha <> a.fec_valor)) -- OMM MAY/2017 DYDMR-6006
       
    union
    select b.fecha, b.hora, b.cod_usuario, nvl(b.monto,0) monto, b.cod_moneda, b.mto_equ_local, b.cotizacion cot_ope,
           pag_gen.FU_OBT_COTIZACION(b.cod_moneda,b.fecha) cot_bcp,
           round(pag_gen.FU_OBT_COTIZACION(b.cod_moneda,b.fecha) * b.monto,0) mto_equ_bcp,
           b.cod_ofi_origen, b.cod_oficina, b.estado, b.reversado, b.nro_secuencia,
           b.cod_mod_padre, b.cod_mad_padre, b.cod_tra_padre, b.cod_modulo, b.cod_modalidad, b.cod_transaccion,
           b.concepto,
           71 cod_mad_cambio,
           a.nro_documento, b.rowid fila, 'N' afe_ope_futura,
           '17' cod_tip_referencia, a.nro_documento2 nro_referencia
       from  ge_movimientos b,ge_movimientos a
       where a.cod_mod_padre = 9 -- CAJA,
         and a.cod_tra_padre in (388,486)  -- Transf. HB
         and a.estado = 'N'
         and a.cod_transaccion = 602
         and a.monto <> 0
         and b.cod_mod_padre = 9
         and b.estado = 'N'
         and b.cod_transaccion = 503
         and b.fecha = a.fecha
         and b.cod_usuario = a.cod_usuario
         and b.hora = a.hora
         and b.nro_documento = a.nro_documento
         and b.cod_moneda <> a.cod_moneda
         and b.monto <> 0
         and b.cod_moneda <> v_cod_mon_local
         and ((a.reversado = 'N') OR (a.reversado = 'S' and a.fecha <> a.fec_valor)) -- OMM MAY/2017 DYDMR-6006
    union
    select b.fecha, b.hora, b.cod_usuario, nvl(b.monto,0) monto, b.cod_moneda, b.mto_equ_local, b.cotizacion cot_ope,
           pag_gen.FU_OBT_COTIZACION(b.cod_moneda,b.fecha) cot_bcp,
           round(pag_gen.FU_OBT_COTIZACION(b.cod_moneda,b.fecha) * b.monto,0) mto_equ_bcp,
           b.cod_ofi_origen, b.cod_oficina, b.estado, b.reversado, b.nro_secuencia,
           b.cod_mod_padre, b.cod_mad_padre, b.cod_tra_padre, b.cod_modulo, b.cod_modalidad, b.cod_transaccion,
           b.concepto,
           CASE WHEN b.monto >= 0 THEN 72
                WHEN b.monto < 0 then 71 end cod_mad_cambio,
           a.nro_documento, b.rowid fila, 'N' afe_ope_futura,
           CASE WHEN b.monto >= 0 THEN '31'
                WHEN b.monto <  0 THEN '17' end cod_tip_referencia, a.nro_documento2 nro_referencia
      from ge_movimientos b, ge_movimientos a
     where a.cod_mod_padre = 9
       and a.cod_tra_padre =411  -- TRANSF.HB
       and a.estado = 'N'
       and a.cod_transaccion = 503
       and a.monto <> 0
       and b.cod_mod_padre = 9
       and b.estado = 'N'
       and b.cod_transaccion = 74
       --and b.tip_mov_rubro = 'C'
       and b.fecha = a.fecha
       and b.cod_usuario = a.cod_usuario
       and b.hora = a.hora
       and b.nro_documento = a.nro_documento
       and b.cod_moneda <> a.cod_moneda
       and b.monto <> 0
       and b.cod_moneda <> v_cod_mon_local
       and ((a.reversado = 'N') OR (a.reversado = 'S' and a.fecha <> a.fec_valor)) -- OMM MAY/2017 DYDMR-6006
    union
    select b.fecha, b.hora, b.cod_usuario, nvl(b.monto,0) monto, b.cod_moneda, b.mto_equ_local, b.cotizacion cot_ope,
           pag_gen.FU_OBT_COTIZACION(b.cod_moneda,b.fecha) cot_bcp,
           round(pag_gen.FU_OBT_COTIZACION(b.cod_moneda,b.fecha) * b.monto,0) mto_equ_bcp,
           b.cod_ofi_origen, b.cod_oficina, b.estado, b.reversado, b.nro_secuencia,
           b.cod_mod_padre, b.cod_mad_padre, b.cod_tra_padre, b.cod_modulo, b.cod_modalidad, b.cod_transaccion,
           b.concepto,
           71 cod_mad_cambio,
           a.nro_documento, b.rowid fila, 'N' afe_ope_futura,
           '17' cod_tip_referencia, a.nro_documento2 nro_referencia
       from  ge_movimientos b,ge_movimientos a
       where a.cod_mod_padre = 9 -- CAJA,
         and a.cod_tra_padre =411  -- Transf. HB
         and a.estado = 'N'
         and a.cod_transaccion = 74
        -- and a.tip_mov_rubro = 'C'
         and a.monto <> 0
         and b.cod_mod_padre = 9
         and b.estado = 'N'
         and b.cod_transaccion = 503
         and b.fecha = a.fecha
         and b.cod_usuario = a.cod_usuario
         and b.hora = a.hora
         and b.nro_documento = a.nro_documento
         and b.cod_moneda <> a.cod_moneda
         and b.monto <> 0
         and b.cod_moneda <> v_cod_mon_local
         and ((a.reversado = 'N') OR (a.reversado = 'S' and a.fecha <> a.fec_valor)) -- OMM MAY/2017 DYDMR-6006
    union
    select b.fecha, b.hora, b.cod_usuario, nvl(b.monto,0) monto, b.cod_moneda, b.mto_equ_local, b.cotizacion cot_ope,
           pag_gen.FU_OBT_COTIZACION(b.cod_moneda,b.fecha) cot_bcp,
           round(pag_gen.FU_OBT_COTIZACION(b.cod_moneda,b.fecha) * b.monto,0) mto_equ_bcp,
           b.cod_ofi_origen, b.cod_oficina, b.estado, b.reversado, b.nro_secuencia,
           b.cod_mod_padre, b.cod_mad_padre, b.cod_tra_padre, b.cod_modulo, b.cod_modalidad, b.cod_transaccion,
           b.concepto,
           71 cod_mad_cambio,
           a.nro_documento, b.rowid fila, 'N' afe_ope_futura,
           '17' cod_tip_referencia, a.nro_documento2 nro_referencia
       from  ge_movimientos b,ge_movimientos a
       where a.cod_mad_padre = 455 -- SNP
         and a.cod_tra_padre =303  -- Transf. SNP
         and a.estado = 'N'
         and a.cod_transaccion in (602, 196)
         and a.monto <> 0
         and b.cod_mad_padre = 455
         and b.estado = 'N'
         and b.cod_transaccion in (503, 190)
         and b.fecha = a.fecha
         and b.cod_usuario = a.cod_usuario
         and b.hora = a.hora
         and b.nro_documento = a.nro_documento
         and b.cod_moneda <> a.cod_moneda
         and b.monto <> 0
         and b.cod_moneda <> v_cod_mon_local
         and ((a.reversado = 'N') OR (a.reversado = 'S' and a.fecha <> a.fec_valor))  -- OMM MAY/2017 DYDMR-6006
    union
    select b.fecha, b.hora, b.cod_usuario, nvl(b.monto,0) monto, b.cod_moneda, b.mto_equ_local, b.cotizacion cot_ope,
           pag_gen.FU_OBT_COTIZACION(b.cod_moneda,b.fecha) cot_bcp,
           round(pag_gen.FU_OBT_COTIZACION(b.cod_moneda,b.fecha) * b.monto,0) mto_equ_bcp,
           b.cod_ofi_origen, b.cod_oficina, b.estado, b.reversado, b.nro_secuencia,
           b.cod_mod_padre, b.cod_mad_padre, b.cod_tra_padre, b.cod_modulo, b.cod_modalidad, b.cod_transaccion,
           b.concepto,
           CASE WHEN b.monto >= 0 THEN 72
                WHEN b.monto < 0 then 71 end cod_mad_cambio,
           a.nro_documento, b.rowid fila, 'N' afe_ope_futura,
           CASE WHEN b.monto >= 0 THEN '31'
                WHEN b.monto <  0 THEN '17' end cod_tip_referencia, a.nro_documento2 nro_referencia
      from ge_movimientos b, ge_movimientos a
     where a.cod_mad_padre = 455
       and a.cod_tra_padre = 303  -- TRANSF.SNP
       and a.estado = 'N'
       and a.cod_transaccion in (503, 190)
       and a.monto <> 0
       and b.cod_mad_padre = 455
       and b.estado = 'N'
       and b.cod_transaccion in (602, 196)
       and b.fecha = a.fecha
       and b.cod_usuario = a.cod_usuario
       and b.hora = a.hora
       and b.nro_documento = a.nro_documento
       and b.cod_moneda <> a.cod_moneda
       and b.monto <> 0
       and b.cod_moneda <> v_cod_mon_local
       and ((a.reversado = 'N') OR (a.reversado = 'S' and a.fecha <> a.fec_valor));  -- OMM MAY/2017 DYDMR-6006
   ------------------------------------------------------------------
   r_gmovi            ge_movimientos%rowtype;
   v_mto_utilidad     ge_movimientos.monto%type;
   v_cod_tas_desglose ge_movimientos.cod_tasa%type;
   v_val_tas_desglose ge_movimientos.val_tasa%type;
   v_cod_tra_desglose ge_movimientos.cod_transaccion%type;
   v_val_desglose     ge_movimientos.monto%type;
   v_nro_secuencia    ge_movimientos.nro_secuencia%type:= 990;

   --
   v_ropfu lc_ope_futuras%rowtype;
   v_ind_dev_val_econ ge_par_dinamicos.val_parametro%type;
   v_exi_ope_dev_ant varchar2(1);
   v_usuario    ba_usuarios.cod_usuario%type;
   v_hora       ge_movimientos.hora%type;
   v_can_user      number;
   -- Variable de control para evitar llamadas redundantes
   v_datos_cargados BOOLEAN := FALSE;
BEGIN
   --Recuperamos la cantidad de users con el dominio
   BEGIN
     SELECT COUNT(*)
       INTO v_can_user
       FROM ba_cod_referencias
      WHERE dominio = 'USU_MOV_CIERRE'
        AND abreviatura = 'MOVCIERRE';
   END;
   v_cod_mon_local := pag_gen.fu_obt_mon_local;
   v_fec_actual    := pag_cal.fu_obt_fec_actual(7);
   for reg in c_moneda loop
      v_datos_cargados := FALSE;--Limpiamos la variable al inicio del loop
      if nvl(reg.mto_equ_bcp,0) <> nvl(reg.mto_equ_local,0) then
        if reg.nro_secuencia = 1 then
           v_nro_secuencia := 900;
        else
           v_nro_secuencia := 950;
        end if;
        -- hay diferencia entre lo registrado y la cotizacion de cierre
        v_mto_utilidad := nvl(reg.mto_equ_bcp,0) - nvl(reg.mto_equ_local,0);
        begin
          -- cambio el mto equivalente local por el del cierre
          update ge_movimientos
             set mto_equ_local = nvl(reg.mto_equ_bcp,0)
           where rowid = reg.fila;
          -- se agrego para que actualice el movimiento del cheque gerencia
          update ge_movimientos
             set mto_equ_local = nvl(reg.mto_equ_bcp,0)
           where cod_usuario = reg.cod_usuario
             and fecha = reg.fecha
             and hora = reg.hora
             and cod_modalidad in (43,45)
             and cod_moneda = reg.cod_moneda
             and cod_transaccion = 603
             and reversado = 'N'
             and monto = reg.monto;
        exception
          when others then
            raise_application_error(-20000,'Error al actualizar movimiento, fecha '||reg.fecha||' hora '||reg.hora||' Usuario '||reg.cod_usuario||' secuencia '||reg.nro_secuencia);
        end;
        r_gmovi.fecha          := reg.fecha;
        r_gmovi.fec_valor      := v_fec_actual;
        r_gmovi.cod_ofi_origen := reg.cod_ofi_origen;
        r_gmovi.cod_oficina    := NVL(v_cod_ofi_trading,reg.cod_oficina);
        r_gmovi.estado         := reg.estado;
        r_gmovi.reversado      := reg.reversado;
        r_gmovi.protegido      := 'N';
        r_gmovi.emi_aviso      := 'N';
        r_gmovi.cod_mod_padre  := reg.cod_mod_padre;
        r_gmovi.cod_mad_padre  := reg.cod_mad_padre;
        r_gmovi.cod_tra_padre  := reg.cod_tra_padre;
        r_gmovi.concepto       := reg.concepto;
        if reg.cod_tra_padre in (303, 388, 486,411) then -- AP 2575
           r_gmovi.cod_modulo     := 7;
        else
           r_gmovi.cod_modulo     := reg.cod_mod_padre;
        end if;
        r_gmovi.cod_modalidad  := reg.cod_mad_cambio;
        r_gmovi.nro_documento  := reg.nro_documento;
        r_gmovi.cod_rubro      := null;
        r_gmovi.tip_mov_rubro  := null;
        r_gmovi.cod_transaccion := null;
        r_gmovi.cod_ref_cambio  := reg.cod_tip_referencia;
        r_gmovi.nro_documento2 := reg.nro_referencia;

        if reg.afe_ope_futura = 'S' then
            --//--Proyecto: CNFNORMA-274-AJUSTES FORWARD--//
            v_ind_dev_val_econ := nvl(fug_obt_pardinamico('IND_DEV_VAL_ECONOMICO'),'N');
            -- Carga el registro con los datos de la Operación Futura.
            begin
              select *
                into v_ropfu
                from lc_ope_futuras
               where cod_tip_referencia = reg.cod_tip_referencia
                 and nro_referencia = reg.nro_referencia
                 and estado = 'L';
            exception
              when no_data_found then
                raise_application_error(-20000,'Operación no Existe o no está Aprobada.Nro.Ref:'||reg.nro_referencia||' Cod_tipo: '||reg.cod_tip_referencia);
              when others then
                raise_application_error(-20000,'Error al Buscar Operación. '||reg.nro_referencia||' Cod_tipo: '||reg.cod_tip_referencia||' '||sqlerrm);
            end;
            select decode(nvl(count(*),0),0,'N','S')
              into v_exi_ope_dev_ant
              from ba_cod_referencias a
             where a.dominio = 'OPE_FUT_DEV_ANTERIOR'
               and a.val_minimo = v_ropfu.nro_cuenta||'#'||v_ropfu.nro_operacion;
               
            if ((v_ind_dev_val_econ = 'N') or (v_ind_dev_val_econ = 'S' and v_exi_ope_dev_ant = 'S')) then
                --CIE-941: nuevas funciones de hora y usuario para movimientos
                v_usuario := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE','USU_MOV_CIERRE',V_CAN_USER,'S_USU_MOVCIERRE');
                v_hora    := PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E');
                r_gmovi.hora := v_hora;
                r_gmovi.cod_usuario    := v_usuario;
                r_gmovi.cod_persona := v_ropfu.cod_persona;
                -- reversion de los movimientos de alta de la operacino futura
                r_gmovi.nro_secuencia := nvl(v_nro_secuencia,990);
                v_nro_secuencia := v_nro_secuencia + 1;
                r_gmovi.cod_moneda    := v_ropfu.cod_moneda;
                r_gmovi.monto         := v_ropfu.monto * -1;
                r_gmovi.mto_equ_local := nvl(reg.mto_equ_bcp,0) * -1;
                r_gmovi.cod_transaccion := 356;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                --
                r_gmovi.nro_secuencia := nvl(v_nro_secuencia,990);
                v_nro_secuencia := v_nro_secuencia + 1;
                r_gmovi.cod_moneda    := v_cod_mon_local;
                r_gmovi.monto         := nvl(reg.mto_equ_local,0) * -1;
                r_gmovi.mto_equ_local := null;
                r_gmovi.cod_transaccion := 357;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            else
                --CIE-941: nuevas funciones de hora y usuario para movimientos
                v_usuario := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE','USU_MOV_CIERRE',V_CAN_USER,'S_USU_MOVCIERRE');
                v_hora    := PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E');
                r_gmovi.hora := v_hora;
                r_gmovi.cod_usuario    := v_usuario;
                --//--Proyecto: CNFNORMA-274-AJUSTES FORWARD--//
                r_gmovi.cod_persona := v_ropfu.cod_persona;
                -- reversion de los movimientos de alta de la operacino futura
                r_gmovi.nro_secuencia := nvl(v_nro_secuencia,990);
                v_nro_secuencia := v_nro_secuencia + 1;
                r_gmovi.cod_moneda    := v_ropfu.cod_moneda;
                r_gmovi.monto         := v_ropfu.monto * -1;
                r_gmovi.mto_equ_local := nvl(reg.mto_equ_bcp,0) * -1;
                r_gmovi.cod_transaccion := 2356;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                --
                v_mto_resultado := (reg.cot_ope * reg.monto) - (reg.cot_bcp * reg.monto);
                if reg.cod_mad_cambio = 71 then
                   if v_mto_resultado >= 0 then 
                      r_gmovi.cod_transaccion := 2358; --Perdida--
                   else
                      r_gmovi.cod_transaccion := 2357; --Ganancia--
                   end if;
                else --Es Venta--
                   if v_mto_resultado >= 0 then 
                      r_gmovi.cod_transaccion := 2357; --Ganancia--
                   else
                      r_gmovi.cod_transaccion := 2358; --Perdida--
                   end if;
                end if;            
                r_gmovi.nro_secuencia := nvl(v_nro_secuencia,990);
                v_nro_secuencia := v_nro_secuencia + 1;
                r_gmovi.cod_moneda    := v_cod_mon_local;
                r_gmovi.monto         := abs(nvl(v_mto_resultado,0));
                r_gmovi.mto_equ_local := null;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            end if;
        else
          begin
            select nvl(cod_persona, nro_documento2)
              into r_gmovi.cod_persona
              from ge_movimientos
             where cod_usuario = reg.cod_usuario
               and hora = reg.hora
               and fecha = reg.fecha
               and cod_transaccion = 760;
          exception
             when others then
               r_gmovi.cod_persona := null;
          end;

          ----------------------------------------------------------------
          --1. Genera regitros en el GE_MOVIMIENTOS                     --
          ----------------------------------------------------------------
          if (reg.cod_mad_cambio = 71 and v_mto_utilidad > 0)  or
             (reg.cod_mad_cambio = 72 and v_mto_utilidad < 0) then
             --- Cargar movimiento de utilidad - ganancia
             v_nro_secuencia := v_nro_secuencia + 1;
             r_gmovi.nro_secuencia := nvl(v_nro_secuencia,990);
             v_nro_secuencia := v_nro_secuencia + 1;
             r_gmovi.cod_moneda    := v_cod_mon_local;
             r_gmovi.monto         := abs(v_mto_utilidad);
             r_gmovi.mto_equ_local := null;
             r_gmovi.cod_transaccion := 783;
             --pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
          elsif (reg.cod_mad_cambio = 72 and v_mto_utilidad > 0)  or
             (reg.cod_mad_cambio = 71 and v_mto_utilidad < 0) then
             --- Cargar movimiento de utilidad - perdida
             v_nro_secuencia := v_nro_secuencia + 1;
             r_gmovi.nro_secuencia := nvl(v_nro_secuencia,990);
             v_nro_secuencia := v_nro_secuencia + 1;
             r_gmovi.cod_moneda    := v_cod_mon_local;
             r_gmovi.monto         := abs(v_mto_utilidad);
             r_gmovi.mto_equ_local := null;
             r_gmovi.cod_transaccion := 784;
            --
          end if;

          --
          PRG_OBT_DESGLOSE(reg.cod_ofi_origen,null,v_cod_mon_local,reg.mto_equ_local,
                           r_gmovi.cod_modulo, r_gmovi.cod_modalidad, nvl(r_gmovi.cod_transaccion,784),
                           v_cod_tra_desglose, v_cod_tas_desglose, v_val_tas_desglose,
                           v_val_desglose);
          -- Calcula la Comisión correspondiente.
          v_val_desglose := round(reg.mto_equ_local * v_val_tas_desglose / 100,fue_dec_mon_local);
          --
          if r_gmovi.cod_transaccion = 784 then
             -- Pérdida Suma la comisión
             r_gmovi.monto := r_gmovi.monto + nvl(v_val_desglose,0);
          else
             -- Ganancia Resta la comisión
             r_gmovi.monto := r_gmovi.monto - nvl(v_val_desglose,0);
             -- Si la comisión es Superior a la Ganancia se combierte en una Pérdida.
             if r_gmovi.monto < 0 then
                r_gmovi.monto := abs(r_gmovi.monto);
                r_gmovi.cod_transaccion := 784;
             end if;
          end if;
          -- Cargar el Movimiento por la Perdida o Ganacia
          if r_gmovi.monto > 0 then
             -- -- OMM MAY/2017 DYDMR-6006 Para generar movimiento de en negativo para reversión de historicos
             if reg.monto < 0 then
                r_gmovi.monto := (r_gmovi.monto * -1) ;
             end if ;
             --CIE-941: nuevas funciones de hora y usuario para movimientos
             v_usuario := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE','USU_MOV_CIERRE',V_CAN_USER,'S_USU_MOVCIERRE');
             v_hora    := PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E');
             v_datos_cargados := TRUE; -- se marca que ya tenemos usuario y hora
             r_gmovi.hora := v_hora;
             r_gmovi.cod_usuario    := v_usuario;
             pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
          end if;
          --- Cargar movimiento por el desglose
          r_gmovi.nro_secuencia := nvl(v_nro_secuencia,990);
          v_nro_secuencia := v_nro_secuencia + 1;
          r_gmovi.cod_moneda    := v_cod_mon_local;
          r_gmovi.monto         := v_val_desglose;
          r_gmovi.mto_equ_local := null;
          r_gmovi.cod_transaccion := v_cod_tra_desglose;
          r_gmovi.cod_tasa := v_cod_tas_desglose;
          r_gmovi.val_tasa := v_val_tas_desglose;
          --
          if r_gmovi.monto > 0 then
            -- si el primer IF no se ejecuto, necesitamos cargar los datos aca
            IF NOT v_datos_cargados THEN
              --CIE-941: nuevas funciones de hora y usuario para movimientos
              v_usuario := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE','USU_MOV_CIERRE',V_CAN_USER,'S_USU_MOVCIERRE');
              v_hora    := PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E');
            END IF;
            r_gmovi.hora        := v_hora;
            r_gmovi.cod_usuario := v_usuario;
            pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
          end if;
        end if;
      end if;
      -------------------------------------------------------------
      v_cont := v_cont+1;
      IF MOD(v_cont, 500) = 0  THEN
         v_mensaje := 'PRL_GEN_ASI_UTI_OEP-registro ' || v_cont;
         DBMS_APPLICATION_INFO.SET_CLIENT_INFO(v_mensaje);
      END IF; 
   END LOOP;
END;
/
