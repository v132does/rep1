CREATE OR REPLACE PROCEDURE IT.PRP_REV_CAR_SEGUROS
       IS
   v_fec_actual DATE := pag_cal.fu_obt_fec_actual(6);
   v_fec_valor  date;
   v_ult_fec_mes date;
   v_nro_cuenta GE_cuentas.nro_cuenta%type;
   
   -- Variables de mejora --
   v_usuario         ba_usuarios.cod_usuario%type:=user;
   v_hora            ge_movimientos.hora%type:=fug_ini_hora(SYSDATE,'HH24:MI:SS');
   v_can_user        number;
   -- coleccion para manejar nro_secuencia por cod_usuario de manera mas equitativa 
   TYPE typ_usu_secuencia IS TABLE OF NUMBER INDEX BY VARCHAR2(50);
   v_usu_secuencia typ_usu_secuencia;
   
   TYPE t_usu_hor IS TABLE OF VARCHAR2(8) INDEX BY VARCHAR2(15);
   v_usu_hora t_usu_hor;

   cursor c_movimientos is
   select distinct fec_valor, nro_cuenta
   from   ge_movimientos
   where  cod_tra_padre = 358 -- Desembolso de Prestamos
   and    fecha = v_fec_actual
   and    cod_modulo = 6
   and    reversado = 'S';
   ---
   cursor c_cargos is 
   select fecha, hora, cod_usuario, nro_secuencia, monto, nro_cuenta,
          cod_tra_padre, cod_transaccion, cod_rubro, cod_ofi_origen,
          cotizacion, cod_modulo, cod_modalidad, referencia,
          cod_mod_padre, cod_mad_padre, cod_persona
   from   pr_movimientos_his
   where  fecha = v_fec_valor
   and    referencia = v_nro_cuenta
   and    cod_tra_padre in (371,365) -- Cargos por seguro en cuotas
   and    cod_mod_padre = 6
   and    reversado = 'N'
   and    monto > 0
   union
   select fecha, hora, cod_usuario, nro_secuencia, monto, nro_cuenta,
          cod_tra_padre, cod_transaccion, cod_rubro, cod_ofi_origen,
          cotizacion, cod_modulo, cod_modalidad, referencia,
          cod_mod_padre, cod_mad_padre, cod_persona
   from   pr_movimientos_his
   where  fecha = v_ult_fec_mes
   and    referencia = v_nro_cuenta
   and    cod_tra_padre in (371,365) -- Cargos por seguro en cuotas
   and    cod_mod_padre = 6
   and    reversado = 'N'
   and    monto > 0
   order by fecha, hora, nro_secuencia;
   ---
   --inicializa hora para los movimientos
   v_nro_secuencia ge_movimientos.nro_secuencia%type := 0;
   v_nro_comprobante number;
   v_procesa         varchar2(1);
   v_nvo_estado      varchar2(1);
   v_sal_disponible  number;

BEGIN
   -- Obtener cantidad de usuarios una sola vez antes de los loops --
   BEGIN
     SELECT COUNT(*)
       INTO v_can_user
       FROM ba_cod_referencias
      WHERE dominio = 'USU_MOV_CIERRE'
        AND abreviatura = 'MOVCIERRE';
   END;
   /*
   || recorre los mov historicos reversados y se
   || inserta en ge_movimientos mov. inversos
   */
   for i in c_movimientos loop
      v_fec_valor := i.fec_valor;
      v_nro_cuenta := i.nro_cuenta;
      v_ult_fec_mes :=  last_day(to_date('01/'||to_char(v_fec_valor,'MM/YYYY'),'DD/MM/YYYY'));
      v_ult_fec_mes := pag_cal.FU_OBT_FEC_HABIL(v_ult_fec_mes,-1,null);
      for j in c_cargos loop
         if nvl(j.cod_transaccion,0) = 602 then
            v_nro_secuencia := nvl(v_nro_secuencia,0) + 1; 
            v_procesa := 'N';
            -- Se debe debitar de la cuenta de la aseguradora
            pag_cta.PR_OBT_CUENTA(j.nro_cuenta);
            pag_cta.G_COD_ERROR := 0;
            -- verifico si puedo o no cobrar
            pag_cta.PR_VER_OPERACION(j.nro_cuenta,
                                     j.cod_tra_padre, -- padre
                                     j.cod_modulo,
                                     j.cod_modalidad,
                                     'D', -- TIPO DEBITO
                                     pag_cta.G_CTAS.cod_moneda,
                                     j.monto,
                                     pag_cta.G_CTAS.cod_oficina,
                                     pag_cta.G_CTAS.COD_MODULO,
                                     pag_cta.G_CTAS.COD_MODALIDAD,
                                     v_nvo_estado,
                                     v_sal_disponible,
                                     v_procesa,
                                     503);
                                     
            if v_procesa = 'N' then  -- no se puede debitar
               -- RI : 02/02/2010 : Si la cuenta esta inactiva y no tiene saldo no se graba mov.pendiente
               If  v_sal_disponible = 0 and pag_cta.g_ctas.estado = 'I' then
                   null;
               else
                  insert into ge_mov_pendientes
                             (nro_cuenta,fecha, cod_modulo, cod_modalidad, cod_transaccion,
                              cod_mod_padre, cod_mad_padre, cod_tra_padre, monto,
                              hora, cod_usuario,  cod_moneda,
                              cod_oficina, cod_error, estado, cod_ofi_origen,
                              concepto, cod_tasa, val_tasa, nro_documento, saldo,
                              motivo, referencia, cod_persona)
                      values (j.nro_cuenta, j.fecha, j.cod_modulo, j.cod_modalidad, 503,
                              j.cod_mod_padre, j.cod_mad_padre, j.cod_tra_padre, j.monto,
                              v_hora, user, pag_cta.G_CTAS.cod_moneda,
                              pag_cta.g_ctas.cod_oficina, pag_cta.g_cod_error, 'I', pag_cta.G_CTAS.cod_oficina,
                              'Cargo por Pago de Cheque',null, null,
                              j.nro_cuenta /* nro_documento=cuenta*/, j.monto,
                              pag_cta.G_MSJ_ERROR, j.referencia, j.cod_persona);
               End if;             
            else
               pag_cta.pr_act_operacion(
                             j.nro_cuenta,
                             v_hora,                   --HORA
                             'D',
                             pag_cta.g_ctas.cod_moneda,-- Moneda de la Operacion
                             j.monto,
                             j.cod_tra_padre,          -- COD_TRA_PADRE (Cargos por Seguros)
                             503,                      -- COD_TRA_HIJO
                             null,                     -- r_pcpre.nro_cuenta,
                             j.cotizacion,             -- COTIZACION
                             j.cod_ofi_origen,         -- cod_ofi_origen
                             j.cod_modulo,             -- cod_mod_padre
                             j.cod_modalidad,          -- cod_mad_padre
                             null,                     -- cod_tasa
                             null,                     -- val_tasa
                             'Debito Reversion Cargos de Seguro '||j.referencia,
                             'S',                      -- emi_aviso
                             v_nro_secuencia,
                             v_Fec_actual);
               if pag_cta.fu_obt_cod_error() <> 0 then
                  raise_application_error(-20000, 'Deb.Seguro '||pag_cta.fu_obt_cod_error()||  ' - '|| pag_cta.fu_obt_msj_error());
               Else
                  --- Graba el numero de comprobante para que pueda imprimir...
                  select s_nro_debito.nextval into v_nro_comprobante from dual;
                  --
                  update ge_movimientos
                  set    nro_documento3 = v_nro_comprobante,
                         referencia = j.referencia
                  where  hora = v_hora
                  and    cod_usuario = user
                  and    cod_tra_padre = 365
                  and    concepto = 'Debito Reversion Cargos de Seguro '||j.referencia;
               end if;
            end if;
         else
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
            insert into ge_movimientos
                  (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
                   cod_tra_padre,cod_transaccion,fecha,fec_valor,
                   monto,estado,concepto,reversado,
                   cod_mod_padre,cod_mad_padre,cod_usuario,hora,
                   nro_secuencia,nro_cuenta,cod_ofi_origen,
                   cod_rubro,tip_mov_rubro, referencia, cod_persona)
            select cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
                   cod_tra_padre,cod_transaccion,v_fec_actual,v_fec_actual,
                   monto * -1,estado,'Debito Reversion Cargos de Seguro '||j.referencia,reversado,
                   cod_mod_padre,cod_mad_padre, v_usuario,v_usu_hora(v_usuario),
                   v_usu_secuencia(v_usuario),nro_cuenta,cod_ofi_origen,
                   cod_rubro,tip_mov_rubro,
                   referencia, cod_persona
              from pr_movimientos_his
             where fecha = j.fecha
               and hora = j.hora
               and cod_usuario = j.cod_usuario
               and nro_secuencia = j.nro_secuencia
               and cod_tra_padre in (371,365) -- Cargos por seguro en cuotas
               and cod_modulo = 6
               and reversado = 'N'
               and monto > 0
               order by nro_secuencia;
         end if;
         --obtener sig segundo para el prox ciclo
         --para q no caiga por pk
         --sig segundo x si hay mas de 999 reg.
         if v_nro_secuencia >= 995 then
            v_hora := PAG_GEN.FU_OBT_SIG_SEGUNDO(v_hora);
            v_nro_secuencia := 1;
         end if;
      end loop;
   end loop;
--------------------------------------------------------------------
EXCEPTION
 WHEN OTHERS THEN
    raise_application_error(-20000, 'ERROR. Reversión Cargos Seguros '||SQLERRM);
END PRP_REV_CAR_SEGUROS;
