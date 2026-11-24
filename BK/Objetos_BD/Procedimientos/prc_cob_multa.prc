CREATE OR REPLACE PROCEDURE IT.PRC_COB_MULTA
 (p_nro_cuenta   in ge_cuentas.nro_cuenta%type default null,
 p_nro_cheque    in cc_che_devueltos.nro_cheque%type default null,
 p_fecha         in date default null,
 p_hora          in ge_movimientos.hora%type default null,
 p_nro_secuencia in number default null)

 IS
 /* proceso de cobro de multa a ejecutarse por cuenta y/o
   diariamente a fin de cobrar las multas pendientes */
  v_fecha    DATE := nvl(p_fecha,pag_cal.FU_OBT_FEC_ACTUAL(4));
  v_hora     ge_movimientos.hora%type := nvl(p_hora,fug_ini_hora(sysdate,'HH24:MI:SS'));

  v_cobrar        varchar2(1):='N';
  v_cod_tasa      ge_movimientos.cod_tasa%type;
  v_val_tasa      ge_movimientos.val_tasa%type;
  rv_pres         pr_cta_prestamos%rowtype;
  r_gmovi         ge_movimientos%rowtype;
  v_nro_secuencia ge_movimientos.nro_secuencia%type;
  v_mto_pagado ge_movimientos.monto%type;
  v_cod_modulo    ge_cuentas.cod_modulo%type;
  v_cod_modalidad ge_cuentas.cod_modalidad%type;
  v_cod_moneda    ge_cuentas.cod_moneda%type;
  v_cod_oficina   ge_cuentas.cod_oficina%type;
  v_sal_cuenta    ge_cuentas.sal_contable%type;
  v_cod_tra_multa ge_movimientos.cod_transaccion%type;
  v_cod_causa     ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_CAU_MULTA');
  v_programa      ge_log_errores.cod_programa%type :='PRC_COB_MULTA';  
  v_det_error     varchar2(4000);
  v_usuario       ba_usuarios.cod_usuario%type;
  v_can_user      number;
   TYPE typ_usu_secuencia IS TABLE OF NUMBER INDEX BY VARCHAR2(50);
   v_usu_secuencia typ_usu_secuencia;  
   TYPE t_usu_hor IS TABLE OF VARCHAR2(8) INDEX BY VARCHAR2(15);
   v_usu_hora t_usu_hor;
  

cursor cheques is
  select nro_cuenta, multa, sal_multa, cod_causa, rowid, nro_cheque
    from cc_che_devueltos
   where nro_cuenta = nvl(p_nro_cuenta, nro_cuenta)
     and nro_cheque = nvl(p_nro_cheque, nro_cheque)
     AND INSTR(',' || v_cod_causa || ',', ',' || cod_causa || ',') > 0
     and sal_multa >0;--q tenga saldo
   
   
BEGIN
  v_det_error := NULL;
  --Obtener cantidad de usuarios de cierre
  BEGIN
    SELECT COUNT(*)
      INTO v_can_user
      FROM ba_cod_referencias
     WHERE dominio = 'USU_MOV_CIERRE'
       AND abreviatura = 'MOVCIERRE';
  END;
  --x tipo de implementación
  if fug_obt_tip_implementacion in (1,7) then
    if v_fecha is null then
      v_fecha := pag_cal.fu_obt_fec_actual(1); -- fecha de hoy
    end if;
       
    if p_nro_cuenta is null then
       v_nro_secuencia := 0;
    else
       v_nro_secuencia := NVL(p_nro_secuencia,0);
    end if;
    
    for reg in cheques loop
       --limpiar variables en cada ciclo, puede haber varios cheques por la misma cuenta y el saldo se va actualizando
      v_cod_modulo    := null;
      v_cod_modalidad := null;
      v_cod_oficina   := null;
      v_cod_moneda    := null;
      v_sal_cuenta    := null;
      v_cod_tra_multa := null;
      v_mto_pagado    := null;
      v_cobrar        := 'N';
      v_det_error     := null;      
      --obtener datos de la cuenta
      pag_cta.PR_OBT_CUENTA(reg.nro_cuenta);
      v_cod_modulo    := pag_cta.G_CTAS.cod_modulo;
      v_cod_modalidad := pag_cta.G_CTAS.cod_modalidad;
      v_cod_oficina   := pag_cta.G_CTAS.cod_oficina;
      v_cod_moneda    := pag_cta.G_CTAS.cod_moneda;
      v_sal_cuenta    := nvl(pag_cta.g_ctas.sal_total,0) - nvl(pag_cta.g_ctas.sal_retenido,0)
                         - nvl(pag_cta.g_ctas.sal_bloqueado,0);
      v_cod_tra_multa := fug_obt_parcausales(reg.cod_causa,'COD_TRA_MULTA');
     if v_cod_tra_multa is null then
        v_det_error := 'No existe Transacción para Multa en Causales. Cod Causa: ' || reg.cod_causa;
        it.prg_ins_log_programas(
           p_cod_programa => v_programa,
           p_det_error    => v_det_error,
           p_cod_persona  => null,
           p_nro_cuenta   => reg.nro_cuenta
        );
        -- Forzamos a no cobrar para saltar la lógica siguiente en este ciclo --
        v_cobrar := 'N';
      else
          -- Si existe la transacción, continuamos con la lógica normal --
      v_cobrar := pag_cta.FU_VER_TRA_PROHIBIDA(reg.nro_cuenta,v_cod_tra_multa,v_cod_modulo,v_cod_modalidad);
      --- Se calcula la multa para insertar el monto exonerado
      if reg.sal_multa >= v_sal_cuenta then
         v_mto_pagado := v_sal_cuenta;
      else
         v_mto_pagado := reg.sal_multa;
      end if;
      ---
      if v_cobrar = 'S' then -- tiene transaccion prohibida
         v_cobrar := 'N';
         /*
         || PCC-Exoneración y Extorno de Comisiones y Tasas
         || Se inserta si es una transacción prohibida
         */
         prg_ins_exoneracion(v_cod_tra_multa, v_cod_modulo,
                             v_cod_modalidad, v_cod_moneda,
                             reg.nro_cuenta, null, v_cod_tasa,
                             v_mto_pagado, reg.sal_multa, null,
                             v_mto_pagado);
      else
         v_cobrar := 'S';
      end if;
     end if;       
      If v_cobrar = 'S' then
         --si tiene saldo generar el mov por la multa y cobrar
         if v_sal_cuenta > 0 then
          --procesa
             v_usuario  := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE','USU_MOV_CIERRE',V_CAN_USER,'S_USU_MOVCIERRE');         
             -- primera vez cada usuario es 0
             IF NOT v_usu_secuencia.EXISTS(v_usuario) THEN
                   v_usu_secuencia(v_usuario) := 0;
                   v_usu_hora(v_usuario) := PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E');
             END IF;
                      
             if v_usu_secuencia(v_usuario) = 995 then
                v_usu_hora(v_usuario) := PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E');
                v_usu_secuencia(v_usuario) := 0;
             end if;
            -- para cada usuario voy aumentando la secuencia
            v_usu_secuencia(v_usuario) := v_usu_secuencia(v_usuario) + 1;

            r_gmovi.nro_secuencia   := v_usu_secuencia(v_usuario);
            r_gmovi.cod_usuario     := v_usuario;
            r_gmovi.hora            := v_usu_hora(v_usuario);
            r_gmovi.fecha           := v_fecha;
            r_gmovi.nro_cuenta      := reg.nro_cuenta;
            r_gmovi.cod_modulo      := v_cod_modulo;
            r_gmovi.cod_modalidad   := v_cod_modalidad;
            r_gmovi.cod_oficina     := v_cod_oficina;
            r_gmovi.cod_moneda      := v_cod_moneda;
            r_gmovi.fec_valor       := v_fecha;
            r_gmovi.cod_tra_padre   := v_cod_tra_multa;--padre
            r_gmovi.cod_mod_padre   := v_cod_modulo;
            r_gmovi.cod_mad_padre   := v_cod_modalidad;
            r_gmovi.cod_transaccion := v_cod_tra_multa;--multa
            r_gmovi.monto           := v_mto_pagado;
            r_gmovi.nro_documento   := reg.nro_cheque;
            r_gmovi.cod_tasa        := v_cod_tasa;
            r_gmovi.val_tasa        := v_val_tasa;
            r_gmovi.cotizacion      := null;
            r_gmovi.cod_ofi_origen  := v_cod_oficina;
            r_gmovi.emi_aviso       := 'N';
            r_gmovi.protegido       := 'N';
            r_gmovi.concepto        := 'Cobro de multa';
            r_gmovi.estado          := 'N';
            r_gmovi.reversado       := 'N';
            r_gmovi.mto_equ_local   := null;
            pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

            --actualizar cheques devueltos
            update cc_che_devueltos
               set sal_multa = sal_multa - v_mto_pagado
             where rowid = reg.rowid;

             --actualizar el saldo de la cuenta corriente
            update cc_cta_corrientes
               set sal_total = sal_total - v_mto_pagado
             where nro_cuenta = reg.nro_cuenta;

        end if;
      End if;
    end loop;
  end if;
EXCEPTION
  when others then
    v_det_error := sqlerrm;
    it.prg_ins_log_programas(
       p_cod_programa => v_programa,
       p_det_error    => v_det_error,
       p_cod_persona  => null,
       p_nro_cuenta   => null
    );
END;
