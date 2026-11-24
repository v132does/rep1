CREATE OR REPLACE PROCEDURE IT.PRP_PRO_INI_PRE
 IS
   rv_gcale           ge_calendarios%rowtype;
   v_fcactual         DATE;
   v_nro_cuenta       pr_cta_prestamos.nro_cuenta%TYPE := null;
   v_programa         ba_programas.cod_programa%type := null;

   -- Variable para concatenar las cuentas eliminadas
   v_cuentas_log      VARCHAR2(500) := ''; -- Reducido el tamaño inicial por eficiencia
   v_cant_procesadas  NUMBER := 0;
   
   -- Constantes y variables para el control estricto del buffer de log
   c_msg_base         CONSTANT VARCHAR2(50)  := 'JOB PRP_PRO_INI_PRE. Ctas eliminadas: [';
   c_msg_cierre       CONSTANT VARCHAR2(5)   := ']';
   c_limite_max       CONSTANT NUMBER        := 500;
   -- Espacio seguro neto para acumular cuentas (~445 caracteres)
   c_max_neto_cuentas CONSTANT NUMBER        := c_limite_max - (LENGTH(c_msg_base) + LENGTH(c_msg_cierre));

   --- Cursor de prestamos aprobados y cancelados en el dia
   cursor c_aprobados is
   select prc.nro_cuenta
     from pr_cta_prestamos prc
    where prc.fec_cancelacion = v_fcactual
    and prc.estado = 'N'
    and exists (select 1 from ge_movimientos mov
                where mov.fecha = prc.fec_cancelacion
                and mov.NRO_CUENTA = prc.nro_cuenta
                and mov.COD_TRA_PADRE = 358
                and mov.REVERSADO = 'S');

 PROCEDURE LP_DESCONSOLIDAR_REV (P_NRO_CUENTA IN VARCHAR2) IS
    TYPE r_reversion IS RECORD (
        nro_documento4   ge_movimientos.nro_documento4%TYPE,
        monto            ge_con_tra_procesos.monto%TYPE,
        mto_equ_local    ge_con_tra_procesos.mto_equ_local%TYPE,
        fecha            ge_con_tra_procesos.fecha%TYPE,
        hora             ge_con_tra_procesos.hora%TYPE,
        cod_usuario      ge_con_tra_procesos.cod_usuario%TYPE,
        nro_secuencia    ge_con_tra_procesos.nro_secuencia%TYPE
    );

    TYPE t_reversion IS TABLE OF r_reversion;
    l_reversiones t_reversion;
    v_cant_mov NUMBER(10);
    CURSOR v_rev IS
        select eli.nro_documento4,
               NVL(p.monto, 0) AS monto,
               NVL(p.mto_equ_local, 0) AS mto_equ_local,
               p.fecha,
               p.hora,
               p.cod_usuario,
               p.nro_secuencia
        from ge_movimientos eli,
             ge_con_tra_procesos p
        where eli.fecha = p.fecha
        and   eli.hora = p.hora
        and   eli.cod_usuario = p.cod_usuario
        and   eli.nro_secuencia = p.nro_secuencia
        and   eli.nro_documento4 = p.nro_referencia
        and   p.procesado = 'S'
        and exists (select 1 from ge_movimientos mov
                      where mov.nro_cuenta = P_NRO_CUENTA
                      and mov.fecha = eli.fecha
                      and mov.cod_usuario = eli.cod_usuario
                      and mov.hora = eli.hora);

    BEGIN
        OPEN v_rev;
        FETCH v_rev BULK COLLECT INTO l_reversiones;
        CLOSE v_rev;

        IF l_reversiones.COUNT > 0 THEN
            FOR i IN 1..l_reversiones.COUNT LOOP
                BEGIN
                    SELECT c.cantidad
                    INTO v_cant_mov /*La cantidad de registros asociados al numero de referencia*/
                    FROM ge_con_transacciones c
                    WHERE c.fecha = l_reversiones(i).fecha
                      AND c.nro_referencia = l_reversiones(i).nro_documento4;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        v_cant_mov := 0;
                END;
                /*Si la cantidad es 1 registro, elimina para volver a reprocesar*/
                IF v_cant_mov = 1 THEN
                    DELETE ge_con_transacciones c
                    WHERE c.nro_referencia = l_reversiones(i).nro_documento4
                    AND   c.fecha = l_reversiones(i).fecha;
                ELSE /*Si es mayor a 1, resta la cantidad y montos asociados al numero de referencia*/
                    UPDATE ge_con_transacciones c
                    SET   c.cantidad = c.cantidad - 1,
                          c.total = c.total - l_reversiones(i).monto,
                          c.tot_mon_local = c.tot_mon_local - l_reversiones(i).mto_equ_local
                    WHERE c.nro_referencia = l_reversiones(i).nro_documento4
                    AND   c.fecha = l_reversiones(i).fecha;
                END IF;
                /*Modificamos de la tabla ge_con_tra_procesos el registro*/
                BEGIN
                    UPDATE ge_con_tra_procesos c
                    SET    MENSAJE = P_NRO_CUENTA
                    WHERE   c.fecha = l_reversiones(i).fecha
                        AND c.hora = l_reversiones(i).hora
                        AND c.cod_usuario = l_reversiones(i).cod_usuario
                        AND c.nro_secuencia = l_reversiones(i).nro_secuencia;
                END;
            END LOOP;
        END IF;

    END LP_DESCONSOLIDAR_REV;
begin
   rv_gcale    := pag_cal.fu_obt_reg_cal(6);
   v_fcactual  := rv_gcale.fec_actual;
   pre_ini_aplicacion;--inicalizamos valores de PAE_CNF
   pae_cnf.g_cod_modulo := 1;
   --guardamos el valor original de la variable global
   v_programa := pae_cnf.G_PROGRAMA;
   --seteamos G_PROGRAMA a GPELICTA para pasar de largo las validaciones del trigger TB_GE_CTA_CLIENTES
   pae_cnf.G_PROGRAMA := 'GPELICTA';

   -- Borrar los prestamos de PR_CTA_PRESTAMOS que fueron abiertos y
   -- cancelados el mismo dia
   for reg in c_aprobados loop
      v_cant_procesadas := v_cant_procesadas + 1;

      -- CONTROL DE DESBORDE (Manejo controlado de buffer)
      -- Si añadir la nueva cuenta supera el límite neto disponible, vaciamos el buffer actual e insertamos al log
      IF v_cuentas_log IS NOT NULL AND 
         (LENGTH(v_cuentas_log) + LENGTH(', ') + LENGTH(reg.nro_cuenta)) > c_max_neto_cuentas THEN
         
         pag_cie.PR_INS_LOG(
            c_msg_base || v_cuentas_log || c_msg_cierre,
            pag_cie.c_log_INFO,
            'AUTONOMOUS_TRANSACTION'
         );
         v_cuentas_log := ''; -- Limpiamos el buffer para arrancar el nuevo lote
      END IF;

      -- Concatenación segura de la cuenta actual
      IF v_cuentas_log IS NULL THEN
         v_cuentas_log := reg.nro_cuenta;
      ELSE
         v_cuentas_log := v_cuentas_log || ', ' || reg.nro_cuenta;
      END IF;

      --Se almacena el nro_cuenta
      v_nro_cuenta := reg.nro_cuenta;
      --CIE-639 RZ se desconsolida movimientos
      LP_DESCONSOLIDAR_REV(reg.nro_cuenta);

      --- Eliminar relacion cliente cuenta
      delete from ge_cta_clientes
       where nro_cuenta = reg.nro_cuenta;

      --- Eliminar garantias
      delete from pr_cta_garantias
       where nro_cuenta = reg.nro_cuenta;
       --eliminar el historico de movimientos de caja
       delete from cj_movimientos_his eli
       where exists (select 1 from cj_movimientos_his mov
                     where mov.nro_cuenta = reg.nro_cuenta
                       and mov.fecha = eli.fecha
                       and mov.cod_usuario = eli.cod_usuario
                       and mov.hora = eli.hora
                       and mov.estado = 'R');
      --- Eliminar movimientos de la cuenta de caja
      delete from cj_movimientos eli
       where exists (select 1 from cj_movimientos mov
                     where mov.nro_cuenta = reg.nro_cuenta
                       and mov.fecha = eli.fecha
                       and mov.cod_usuario = eli.cod_usuario
                       and mov.hora = eli.hora
                       and mov.estado = 'R');
      --- Eliminar movimientos de la cuenta
      delete from ge_movimientos eli
       where exists (select 1 from ge_movimientos mov
                     where mov.nro_cuenta = reg.nro_cuenta
                       and mov.fecha = eli.fecha
                       and mov.cod_usuario = eli.cod_usuario
                       and mov.hora = eli.hora);

/*  porque existen movimientos no reversados atados a la cuenta */
--                        and mov.reversado = 'S');
      --- Eliminar cheques
      delete pr_rel_chq_lib lib
       where exists (select 1 from ge_che_custodias cus
                     where cus.nro_referencia = reg.nro_cuenta
                       and cus.cod_banco = lib.cod_banco
                       and cus.nro_cheque = lib.nro_cheque
                       and cus.cta_libradora = lib.cta_libradora);
      delete from ge_che_custodias cus
       where cus.nro_referencia = reg.nro_cuenta;
      --- Eliminar destinos
      delete from pr_cta_destinos
       where nro_cuenta = reg.nro_cuenta;
      --- Eliminar cuotas
      delete from pr_cuotas
       where nro_cuenta = reg.nro_cuenta;
      --- Eliminar los registros dependientes de ge_cuentas.
      delete from ge_exoneraciones ex
      where ex.nro_cuenta=reg.nro_cuenta;

      delete from ge_cuentas_nov cn
      where cn.nro_cuenta=reg.nro_cuenta;
      --CIE-670 FBDM se elimina registro de ge_cla_operaciones_his
      delete from ge_cla_operaciones_his cl
      where nro_cuenta = reg.nro_cuenta;
      
      --eliminar las actualizaciones de relaciones
      DELETE FROM SB_CTA_VINCULOS_NOV
      where nro_cuenta = reg.nro_cuenta;

      --- Eliminar cuenta de prestamos
      delete from pr_cta_prestamos  prc
       where nro_cuenta = reg.nro_cuenta;
   end loop;

   -- Eliminar tabla de pr_cobros_tmp
   delete pr_cobros_tmp;

   -- Vaciado final: Insertamos el último lote remanente si contiene datos
   IF v_cuentas_log IS NOT NULL THEN
      pag_cie.PR_INS_LOG(
         c_msg_base || v_cuentas_log || c_msg_cierre,
        pag_cie.c_log_INFO,
        'AUTONOMOUS_TRANSACTION'
     );
   END IF;
   commit;
   --asignamos nuevamente el valor original
   pae_cnf.G_PROGRAMA := v_programa;

EXCEPTION
   WHEN OTHERS THEN
     --asignamos nuevamente al valor original
     pae_cnf.G_PROGRAMA := v_programa;
     raise_application_error(-20000,
      'Error en PRP_PRO_INI_PRE. Cuenta: '||v_nro_cuenta||'. Error: '||SQLERRM);
END;
/
