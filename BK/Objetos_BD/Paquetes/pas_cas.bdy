create or replace package body it.PAS_CAS is

g_car_ali       varchar2(1) := 'N';

procedure pr_paq_compilado is
  v_compilado varchar2(1);
BEGIN
  /*
   || procedure creado para el MS siempre que este bien compilado  puede ejecutar
   si hay error el ms lo controla
   */
   v_compilado:= pas_cas.v_compilado;

end pr_paq_compilado;

FUNCTION fu_obt_cod_error return number
IS
   /*
   || Obtiene el código de error del registro del paquete.
   */
BEGIN
   return pas_cas.g_cod_error;
END fu_obt_cod_error;

FUNCTION fu_obt_msj_error return varchar2
IS
   /*
   || Obtiene el mensaje de error contenido en el registro del paquete.
   */
BEGIN
   return pas_cas.g_msj_error;
END fu_obt_msj_error;
/*recupera si persona es Jurido o fisico*/
function fu_obt_tip_per(p_cod_persona in ba_personas.cod_persona%type) return varchar2 is
v_tip_persona varchar2(1);
begin
   select p.tipo
   into v_tip_persona
   from ba_personas p
   where p.cod_persona=p_cod_persona;

   return v_tip_persona;
EXCEPTION
  when no_data_found then
     pas_cas.g_cod_error := 25;
     pas_cas.g_msj_error := 'Código Swift no definido para la persona '||p_cod_persona;
     return NULL;
  when too_many_rows then
     pas_cas.g_cod_error := 25;
     pas_cas.g_msj_error := 'Existe más de un Código Swift para la persona '||p_cod_persona;
     return NULL;
  when others Then
     pas_cas.g_cod_error := 25;
     pas_cas.g_msj_error := 'Error al Obt. Cod. Swift para la persona '||p_cod_persona||' - '||sqlerrm;
     return NULL;
end fu_obt_tip_per;

PROCEDURE pr_ini_variables
IS
  /*
  || Inicializa las variables de error.
  */
BEGIN
   pas_cas.g_cod_error := 0;
   pas_cas.g_msj_error := NULL;
END pr_ini_variables;

FUNCTION fu_obt_cod_swi_participante( p_cod_persona in ba_personas.cod_persona%type ) return varchar
IS
   /*
   || Obtiene el Código Swift del Participante.
   */

   v_cod_swi_entidad ge_bancos.cod_swift%type;
BEGIN
   /*Inicializa las variables de error*/
   pas_cas.pr_ini_variables;
   --
   g_lugar := 'Obteniendo BIC del Participante, ';
   select cod_swift
     into v_cod_swi_entidad
     from gv_snp_participantes
    where cod_persona = p_cod_persona;

   return v_cod_swi_entidad;

EXCEPTION
  when no_data_found then
     pas_cas.g_cod_error := 24;
     pas_cas.g_msj_error := 'Código Swift no definido para la persona '||p_cod_persona;
     return NULL;
  when too_many_rows then
     pas_cas.g_cod_error := 24;
     pas_cas.g_msj_error := 'Existe más de un Código Swift para la persona '||p_cod_persona;
     return NULL;
  when others Then
     pas_cas.g_cod_error := 24;
     pas_cas.g_msj_error := 'Error al Obt. Cod. Swift para la persona '||p_cod_persona||' - '||sqlerrm;
     return NULL;
END fu_obt_cod_swi_participante;


PROCEDURE pr_reg_operacion( p_mensaje   in long,
                            p_respuesta in varchar2 )
IS
   /*
   || Registra LOG de la mensajería
   */

   PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
BEGIN
   insert into ba_log_mensajerias
       (mensaje, respuesta)
     values
       (p_mensaje, substr(p_respuesta,1,4000));
   commit;
EXCEPTION
  when others then
     pas_cas.g_cod_error := 50;
     pas_cas.g_msj_error := sqlerrm;
     raise_application_error(-20000, pas_cas.fu_obt_msj_error);
END;

FUNCTION fu_obt_sig_ref_cas(p_fecha IN GE_SPI_CON_CAS.fecha%type default NULL) return number
IS
   /*
   || Se obtiene el siguiente nro. de referencia, como el campo NRO_DOCUMENTO es NUMBER(15)
   || se calcula 6 digitos para la fecha 'RRMMDD' y 6 digitos para la secuencia.
   */

   v_nro_referencia     GE_SPI_CON_CAS.nro_referencia%type;
   c_fecha              constant date := nvl( p_fecha, g_fec_actual );
   v_existe             char(1) := 'S';
BEGIN

   /*Inicializa las variables de error*/
  pas_cas.pr_ini_variables;
   --
  Begin
     select to_number( to_char( c_fecha, 'RRMMDD' ) || s_nro_ref_cas.nextval )
     into v_nro_referencia
     from dual;
  exception
    when others then
      v_nro_referencia  := null ;
  end;

   /*
   || Se verifica si el número generado no existe aún.
   */
   BEGIN
     select distinct 'S'
       into v_existe
       from GE_SPI_CON_CAS
      where nro_referencia = v_nro_referencia;
   EXCEPTION
      WHEN no_data_found THEN
         v_existe := 'N';
      WHEN others THEN
         v_existe := 'S';
   END;

   if v_existe = 'S' then
      pas_cas.g_cod_error := 34;
      pas_cas.g_msj_error := 'Error en FU_OBT_SIG_REF_CAS: El Nro. Referencia ' || to_char( v_nro_referencia ) ||' generado ya existe.';
   end if;

   -- retorno el sgte nro de referencia
   Return v_nro_referencia;

EXCEPTION
   WHEN OTHERS THEN
      pas_cas.g_cod_error := 35;
      pas_cas.g_msj_error := 'Error en FU_OBT_SIG_NRO_REFERENCIA' || ' - ' || sqlerrm;
      return v_nro_referencia;
END fu_obt_sig_ref_cas;
/*recupera cargos*/
PROCEDURE pr_obt_cargo( p_cod_ofi_cta       in     ge_cuentas.cod_oficina%type
                          ,p_nro_cuenta        in     ge_cuentas.nro_cuenta%type
                          ,p_cod_moneda        in     ge_cuentas.cod_moneda%type
                          ,p_val_transaccion   in     ge_movimientos.monto%type
                          ,p_cod_modulo        in     ge_cuentas.cod_modulo%type
                          ,p_cod_modalidad     in     ge_cuentas.cod_modalidad%type
                          ,p_tas_personalizada in     ge_cuentas.tas_personalizada%type
                          ,p_cod_tra_cargo     in     ge_movimientos.cod_transaccion%type
                          ,p_cod_tas_cargo     in out ge_movimientos.cod_tasa%type
                          ,p_val_tas_cargo        out ge_movimientos.val_tasa%type
                          ,p_val_cargo            out ge_movimientos.val_tasa%type
                         )
   IS
      v_val_transaccion ge_movimientos.monto%type := p_val_transaccion;
      v_fec_vigencia    ge_tas_fechas.fec_vigencia%type;
      v_tip_valor       ge_tasas.tip_valor%type;
      v_tipo            ge_tasas.tipo%type;
      v_redondeo        number(1);
   BEGIN
       v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', p_cod_modulo, p_cod_modalidad, p_cod_moneda);
       -- busco el valor de la tasa
       pag_gen.pr_obt_val_tasa( p_cod_modulo,
                                p_cod_modalidad,
                                p_cod_ofi_cta,
                                p_nro_cuenta,
                                p_cod_moneda,
                                v_val_transaccion,
                                nvl(p_tas_personalizada,'N'),
                                p_cod_tas_cargo,
                                p_cod_tra_cargo,
                                g_fec_actual,
                                p_val_tas_cargo,
                                v_fec_vigencia,
                                v_tip_valor,
                                v_tipo);
          if v_tip_valor = 'V' then
             -- si es un valor, se toma directamente
             p_val_cargo := round( nvl(p_val_tas_cargo,0), v_redondeo );
          else
             -- es un porcentaje
             p_val_cargo := round( nvl( v_val_transaccion, 0 ) * nvl( p_val_tas_cargo, 0 ) / 100, v_redondeo );
             --verificar si el monto a cobrar esta limitado x el minimo y maximo de la tasa
             p_val_cargo := pag_gen.fu_obt_val_final(p_val_cargo);
          end if;

          if p_val_cargo < 0 then
             pas_cas.g_cod_error := 74;
             pas_cas.g_msj_error := 'Error en PR_OBT_CARGO: Monto del Impuesto más alto que el Monto del Cargo';
             raise ex_salir;
          end if;

   EXCEPTION
      when ex_salir then
         raise ex_salir;
      when others then
         pas_cas.g_cod_error := 74;
         pas_cas.g_msj_error := 'Error en LP_OBT_CARGO: '|| sqlerrm;
         raise ex_salir;
   END pr_obt_cargo;
  /*GENERA MOVIMIENTO*/
PROCEDURE pr_gen_mov_cargo( P_referencia         in     ge_movimientos.referencia%type,
                            rg_cta_cliente       in     pag_cta.rg_ctas,
                            p_hora               in     ge_movimientos.hora%type,
                            p_nro_secuencia      in out ge_movimientos.nro_secuencia%type
                          )
IS
   /*Genera movimientos por Cobro de Cargos*/
   v_nro_secuencia     ge_movimientos.nro_secuencia%type   := 0;
   v_hora              ge_movimientos.hora%type            := NULL;
   v_tra_padre         ge_movimientos.cod_transaccion%type := pas_snp.fu_obt_cod_tra_padre; --303
   v_mod_padre         ge_movimientos.cod_mod_padre%type   := pas_snp.fu_obt_cod_mod_padre;
   v_mad_padre         ge_movimientos.cod_mad_padre%type   := pas_snp.fu_obt_cod_mad_padre;
   v_cod_modulo        ge_movimientos.cod_modulo%type      := NULL;
   v_cod_modalidad     ge_movimientos.cod_modalidad%type   := NULL;
   v_tra_debito        ge_movimientos.cod_transaccion%type := pas_snp.fu_obt_cod_tra_cargo;
   v_tra_impuesto      ge_movimientos.cod_transaccion%type := pas_snp.fu_obt_cod_tra_impuesto;
   -- Conversión de Monedas
   v_cot_origen        ge_movimientos.cotizacion%type  := NULL;
   v_cot_destino       ge_movimientos.cotizacion%type  := NULL;
   -- Retorno de verificación de operaciones
   v_est_cuenta        ge_cuentas.estado%type;    -- Estado Cta.
   v_sal_disponible    ge_movimientos.monto%type; -- Sal.Dispon.
   v_procesa           varchar2(1) := 'N';
   -- Definición de Movimientos a ser realizados en el PAS_CAS
   v_con_debito        varchar2(50):= 'Comisión de Alta/Edicion de Alias - BCP';
   v_con_impuesto      varchar2(50):= 'Iva de comisión por Alta/Edicion de Alias - BCP';
   v_tip_mov_debito    varchar2(1) := 'D';
   -- Tasa Vigente para Indemnización al Cliente
   v_fec_vigencia      ge_tas_fechas.fec_vigencia%type := NULL;
   v_tip_valor         ge_tasas.tip_valor%type         := NULL;
   rg_tasas            ge_tasas%rowtype;
   v_cod_tas_horario   ge_tasas.cod_tasa%type       := NULL;
   v_cod_tas_cargo     ge_tasas.cod_tasa%type       := NULL;
   v_val_tas_cargo     ge_movimientos.val_tasa%type := NULL;
   v_cod_tas_impuesto  ge_tasas.cod_tasa%type       := NULL;
   v_val_tas_impuesto  ge_movimientos.val_tasa%type := NULL;
   v_mto_cargo         ge_movimientos.monto%type    := 0;
   v_mto_tra_cargo     ge_movimientos.monto%type    := 0;
   v_mto_impuesto      ge_movimientos.monto%type    := 0;
   v_tot_mto_cargo     ge_movimientos.monto%type    := 0;
   v_valor             ge_movimientos.monto%type    := 0;

   type                t_tipo_cursor IS REF CURSOR;
   v_dominio           ba_cod_referencias.dominio%type;
   cu_datos            t_tipo_cursor;
   v_sql               varchar2(500) := NULL;
   v_condicion         varchar2(500) := NULL;
   v_referencia        varchar2(20) :=  NULL;

   v_usuario          ba_usuarios.cod_usuario%type;
   v_usuario_mod      ba_usuarios.cod_usuario%type;
   v_hora_sal         ge_movimientos.hora%type            := NULL;
BEGIN
  if pas_cas.fu_obt_cod_error = 0  then

     BEGIN
           v_sql := 'select * from ge_tasas where cod_tasa in ( ' || fue_obt_des_refcodes('SPI_CAR_CAS_ALI','COD_TASA') || ' )';
           open cu_datos for v_sql;
           loop
             fetch cu_datos into rg_tasas;
             exit when cu_datos%notfound;
             g_lugar := 'Obteniendo valores para la Tasa, ';
             v_cod_tas_cargo := rg_tasas.cod_tasa;

             pas_cas.pr_obt_cargo( rg_cta_cliente.cod_oficina,
                           rg_cta_cliente.nro_cuenta,
                           rg_cta_cliente.cod_moneda,
                           v_valor,
                           rg_cta_cliente.cod_modulo,
                           rg_cta_cliente.cod_modalidad,
                           nvl(rg_cta_cliente.tas_personalizada,'N'),
                           v_tra_debito,
                           v_cod_tas_cargo,
                           v_val_tas_cargo,
                           v_mto_cargo
                         );

             If  NVL(v_val_tas_cargo,0) > 0 then
                  v_referencia := v_referencia ||','||rg_tasas.cod_tasa;
             end IF;
             v_tot_mto_cargo := v_tot_mto_cargo + nvl( v_mto_cargo,0 );
           end loop;

           close cu_datos;
     EXCEPTION
        when ex_salir then
           raise ex_salir;
        when others then
           pas_cas.g_cod_error := 30;
           pas_cas.g_msj_error := 'Error en PAS_CAS.PR_GEN_MOV_CARGO  ' || g_lugar || sqlerrm;
           close cu_datos;
           raise ex_salir;
     END;

     v_tot_mto_cargo := nvl( v_tot_mto_cargo,0 ) + nvl( v_mto_tra_cargo, 0 );
     BEGIN
        if v_tot_mto_cargo > 0 then
           BEGIN
              g_lugar := 'Calculando Monto del Impuesto, ';
              --
              -- Se obtiene el IVA por el total del CARGO.
              pas_cas.pr_obt_cargo( rg_cta_cliente.cod_oficina,
                            rg_cta_cliente.nro_cuenta,
                            rg_cta_cliente.cod_moneda,
                            v_tot_mto_cargo,
                            rg_cta_cliente.cod_modulo,
                            rg_cta_cliente.cod_modalidad,
                            nvl(rg_cta_cliente.tas_personalizada,'N'),
                            v_tra_impuesto,
                            v_cod_tas_impuesto,
                            v_val_tas_impuesto,
                            v_mto_impuesto
                           );

              v_mto_impuesto := nvl( v_mto_impuesto, 0 );
           EXCEPTION
              when ex_salir then
                 raise ex_salir;
              when others then
                 raise ex_salir;
           END;

          if pas_cas.fu_obt_cod_error = 0 then
             g_lugar := 'Obteniendo el tipo de movimiento para la transacción '||v_tra_debito||', ';
             -- Recupera el tipo de movimiento de la transacción
             v_tip_mov_debito := pas_snp.fu_obt_tip_mov_transaccion( rg_cta_cliente.cod_modulo,
                                                                     rg_cta_cliente.cod_modalidad,
                                                                     v_tra_debito
                                                                   );

             if pas_snp.fu_obt_cod_error <> 0 then
                raise ex_salir;
             end if;

             g_lugar :=  'Verificando los datos de la Cta. ' || rg_cta_cliente.nro_cuenta || ' (3), ' ;
             --
             pag_cta.pr_ver_operacion( rg_cta_cliente.nro_cuenta,               -- Nro.Cta.
                                       v_tra_padre,                             -- Trx. Padre - Transferencia entre cuentas
                                       v_mod_padre,                             -- Mod.Padre
                                       v_mad_padre,                             -- Mad.Padre
                                       v_tip_mov_debito,                        -- Tip.Mov.
                                       rg_cta_cliente.cod_moneda,               -- Cod.Mon.
                                       ( v_tot_mto_cargo + v_mto_impuesto ),    -- Monto Total a Debitar
                                       rg_cta_cliente.cod_oficina,              -- Ofic.Orig.
                                       v_cod_modulo,                            -- Mod.Hijo
                                       v_cod_modalidad,                         -- Mad.Hijo
                                       v_est_cuenta,                            -- Estado Cta.
                                       v_sal_disponible,                        -- Sal.Dispon.
                                       v_procesa                                -- Procesa
                                     );

             if pag_cta.fu_obt_cod_error <> 0 then
                --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                pas_cas.g_cod_error := pag_cta.fu_obt_cod_error;
                pas_cas.g_msj_error := pag_cta.fu_obt_msj_error;

                raise ex_salir;
             end if;

             if not ( rg_cta_cliente.cod_modalidad in ( 31, 41, 43, 47, 38, 39, 334 ) ) then
                pas_cas.g_cod_error := 40;
                pas_cas.g_msj_error := 'Modalidad de la cuenta no permite esta operación';

                raise ex_salir;
             end if;

             --Setea el campo REFERENCIA del movimiento
             pag_cta.pr_set_referencia ( substr( ltrim(v_referencia,','), 1, 20 ) );
             --
             v_hora          := nvl( p_hora, fug_ini_hora );
             v_nro_secuencia := nvl( p_nro_secuencia, v_nro_secuencia );
             
             pas_cas.pr_ver_horario(3);
             /*procedimiento que retorna usuario
              para evitar error de pk en ge_movimientos*/
             prs_snp_obt_usu_hor_movimiento(user,'N',v_usuario_mod,v_hora_sal);  
           /*procedimiento que setea el usuario para evitar 
            error de pk en ge_movimientos*/
             pag_cta.pr_set_variables(v_usuario_mod,null,null,'N','N',
                                      v_nro_secuencia,null,null,null,null);
                                      
             -- Movimiento por el CARGO GRAVADO.                         
             pag_cta.pr_act_operacion( rg_cta_cliente.nro_cuenta,  -- Nro.Cta.
                                       v_hora,                     -- Hora
                                       v_tip_mov_debito,           -- Tip.Mov.
                                       rg_cta_cliente.cod_moneda,  -- Cod.Mon.
                                       v_tot_mto_cargo,            -- Monto
                                       v_tra_padre,                -- Trx.Padre
                                       v_tra_debito,               -- Trx.Hija
                                       P_referencia,               -- Nro.Doc.
                                       NULL,                       -- Cotizacion
                                       fug_obt_ofi_usuario (user), -- Ofic.Orig.
                                       v_mod_padre,                -- Mod.Pad.Cliente
                                       v_mad_padre,                -- Mad.Pad.Cliente
                                       v_cod_tas_cargo,            -- Cod.Tasa
                                       v_val_tas_cargo,            -- Val.Tasa
                                       v_con_debito,               -- Concepto
                                       'S',                        -- Emit.Aviso
                                       v_nro_secuencia,
                                       g_fec_actual,
                                       NULL,
                                       NULL,
                                       NULL
                                     );

             g_lugar :=  'Verificando movimientos registrados para la Cta. (D). ' || rg_cta_cliente.nro_cuenta || ', ' ;
             if pag_cta.fu_obt_cod_error <> 0 then
                --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                pas_cas.g_cod_error := pag_cta.fu_obt_cod_error;
                pas_cas.g_msj_error := pag_cta.fu_obt_msj_error;

                raise ex_salir;
             else -- Movimiento por el IVA del CARGO GRAVADO
                pag_cta.pr_act_operacion( rg_cta_cliente.nro_cuenta,    -- Nro.Cta.
                                          v_hora,                       -- Hora
                                          v_tip_mov_debito,             -- Tip.Mov.
                                          rg_cta_cliente.cod_moneda,    -- Cod.Mon.
                                          v_mto_impuesto,               -- Monto
                                          v_tra_padre,                  -- Trx.Padre
                                          v_tra_impuesto,               -- Trx.Hija
                                          P_referencia,                 -- Nro.Doc.
                                          NULL,                         -- Cotizacion
                                          fug_obt_ofi_usuario (user),   -- Ofic.Orig.
                                          v_mod_padre,                  -- Mod.Pad.Cliente
                                          v_mad_padre,                  -- Mad.Pad.Cliente
                                          v_cod_tas_impuesto,           -- Cod.Tasa
                                          v_val_tas_impuesto,           -- Val.Tasa
                                          v_con_impuesto,               -- Concepto
                                          'S',                          -- Emit.Aviso
                                          v_nro_secuencia,
                                          g_fec_actual,
                                          NULL,
                                          NULL,
                                          NULL
                                        );
                if pag_cta.fu_obt_cod_error <> 0 then
                   --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                   pas_cas.g_cod_error := pag_cta.fu_obt_cod_error;
                   pas_cas.g_msj_error := pag_cta.fu_obt_msj_error;

                   raise ex_salir;
                end if;
             end if;
             p_nro_secuencia := v_nro_secuencia;
          end if;
       end if;
     END;
  end if;
EXCEPTION
   when ex_salir then
      if g_gru_dir_correo is not null then
         BEGIN
            it_mail.mail( fug_obt_dir_correo,
                          g_gru_dir_correo,
                          'Error al generar movimientos para COBRO DE CARGOS - ALIAS',
                          'A continuación los datos de la mensajería: '                                                                || chr(10) || chr(10) ||
                          'Nro. Referencia        : ' || P_referencia                                                               || chr(10) ||
                          'Fecha Valor            : ' || to_char(p_hora,'DD/MM/YYYY')                                            || chr(10) ||
                          'Nro. Cuenta            : ' || rg_cta_cliente.nro_cuenta                                                     || chr(10) ||
                          'Moneda                 : ' || rg_cta_cliente.cod_moneda                                                     || chr(10) ||
                          'Tasa(s) a Cobrar       : ' || substr( v_condicion, 1, 20 )                                                  || chr(10) ||
                          'Mto. Gravado a Debitar : ' || trim(to_char(v_tot_mto_cargo,'999,999,999,999,999.99'))                       || chr(10) ||
                          'Mto. I.V.A. a Debitar  : ' || trim(to_char(v_mto_impuesto,'999,999,999,999,999.99'))                        || chr(10) ||
                          'Error                  : ' || g_lugar || ' ' || pas_cas.g_cod_error || ' - ' || pas_cas.g_msj_error || chr(10) ||
                          chr(10) || chr(10) ||
                          'Atentamente.'
                        );
         EXCEPTION
           when others then
              NULL;
         END;
      end if;
   when others then
      pas_cas.g_cod_error := 60;
      pas_cas.g_msj_error := 'Error en PAS_CAS.PR_GEN_MOV_CARGO: ' || g_lugar || ' - ' || sqlerrm;
END pr_gen_mov_cargo;

PROCEDURE pr_ver_horario(p_cod_modulo in ba_modulos.cod_modulo%type)IS
   v_est_modulo ba_modulos.estado%TYPE;
   v_cod_entidad ge_par_generales.cod_entidad%TYPE;

   BEGIN
      pag_cta.g_horario    := 'D'; -- Dia normal
      v_cod_entidad := pag_gen.fu_obt_cod_entidad();
      --se busca el estado del módulo 3 debido a ser el primer módulo cuyo estado es modificado
      --en el proceso de cierre

      v_est_modulo := pae_cnf.fu_obt_est_modulo(p_cod_modulo);

      IF v_est_modulo = 6 THEN
         -- En cierre.
         pag_cta.g_horario    := 'N'; -- Noche
      ELSIF v_est_modulo = 2 THEN
         -- El modulo esta abierto
         -- Verifica la hora --
         NULL;
      ELSE
        pag_cta.g_horario    := 'N'; -- Noche
      END IF;
 END pr_ver_horario;

procedure pr_ins_consul_cas(p_tip_consulta      in GE_SPI_CON_CAS.tip_consulta%type,
                            p_tip_identificador in GE_SPI_CON_CAS.tip_identificador%type,
                            p_val_identificador in GE_SPI_CON_CAS.val_identificador%type,
                            p_cod_persona       in GE_SPI_CON_CAS.cod_persona%type default null,
                            p_nro_referencia   out GE_SPI_CON_CAS.NRO_REFERENCIA%type) is

v_nro_referencia  GE_SPI_CON_CAS.nro_referencia%type;
v_fecha          GE_SPI_CON_CAS.fecha%type;
v_hora           GE_SPI_CON_CAS.hora%type;
V_solicitud      GE_SPI_CON_CAS.est_solicitud%type;
v_cod_swift      varchar2(20);

begin

 pas_cas.pr_ini_variables;
 /*se controla que el modulo cas este activo para generar las consultas*/
if FUG_OBT_PARDINAMICO('HAB_SPI_CAS') = 'S' then

   v_fecha   := pas_cas.g_fec_actual;
   v_hora    := to_char(sysdate,'HH24:MI:SS');

   v_nro_referencia := pas_cas.fu_obt_sig_ref_cas;
   v_cod_swift:= pas_cas.fu_obt_cod_swi_participante(fug_obt_per_entidad);

     begin
       insert into GE_SPI_CON_CAS(nro_referencia, tip_identificador, val_identificador,
                                   cod_persona, tip_consulta, fecha, hora, est_solicitud,
                                   cod_swi_pte_solicitante)

       values (v_nro_referencia, p_tip_identificador, p_val_identificador, p_cod_persona,
               p_tip_consulta, v_fecha, v_hora, 'U', v_cod_swift);

       p_nro_referencia:= v_nro_referencia;
     exception
       when others then
        pas_cas.g_msj_error := 'Error al insertar datos de la consulta'||sqlerrm;
        pas_cas.g_cod_error := 2;
      end;
  elsif FUG_OBT_PARDINAMICO('HAB_SPI_CAS') = 'N' then
    /*si el parametro esta en N no genera ni una solicitud de consulta*/
    pas_cas.g_msj_error := 'El módulo CAS no se encuentra habilitado.';
    pas_cas.g_cod_error := 30;
  end if;

exception
  when others then
    pas_cas.g_msj_error := 'Error en procedimiento pr_ins_consul_cas'||sqlerrm;
    pas_cas.g_cod_error := 1;
    --raise_application_error(-20000,'Error al insertar datos de la consulta.'||sqlerrm );
end pr_ins_consul_cas;

/*OBTENER CABECERA PARA MS*/
function fu_obt_dat_Cab_concas(p_nro_referencia in GE_SPI_CON_CAS.nro_referencia%type)return typ_obtdatcabconcas
is
v_tip_participante varchar2(2);
v_cod_swift        varchar2(20);
cabecera typ_ObtdatCabconcas := typ_ObtdatCabconcas(null,null,null);
begin
  /*Inicializa las variables de error*/
  pas_cas.pr_ini_variables;

  /*recupera el codigo Swift por el parametro */
 g_lugar:= 'recupera Swift '||p_nro_referencia;
 v_cod_swift := pas_cas.fu_obt_cod_swi_participante(fug_obt_per_entidad);

 /*recupera el tipo de participante*/
  g_lugar:= 'recupera tipo participante '|| p_nro_referencia;

  begin
    select p.tipo
    into v_tip_participante
    from gv_snp_participantes p
    where p.cod_swift=v_cod_swift;
  exception
    when no_data_found then
     v_tip_participante:= null;
  end;

  /*setea cabecera*/
  cabecera:=typ_ObtdatCabconcas(v_tip_participante,v_cod_swift,p_nro_referencia);
  return cabecera;
exception
     when others then
     pas_cas.g_cod_error := 40;
     pas_cas.g_msj_error := 'Error en PAS_CAS.fu_obt_cab_spi'|| ' - ' ||g_lugar || ' - ' || sqlerrm;
     pas_cas.pr_reg_operacion( 'Error al generar cabecera para la referencia ' || p_nro_referencia , g_lugar|| '|' ||pas_cas.g_cod_error );
     cabecera:=typ_ObtdatCabconcas(null,null,null);
     return cabecera;
end;

procedure pr_obt_concas(p_dat_cab_cons_cas    out typ_obtdatcabconcas,
                        p_dat_cons_cas        out typ_ObtConsDatosCas,
                        p_dat_mensaje         out typ_mensajeria_spi )is

v_nro_referencia  GE_SPI_CON_CAS.nro_referencia%type:=null;
datoscas typ_ObtConsDatosCas;
mensaje typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);

cursor con_cas is
select c.nro_referencia,
       c.tip_identificador,
       c.val_identificador,
       c.cod_persona,
       c.tip_consulta,
       c.fecha,
       c.hora,
       c.est_solicitud
 from GE_SPI_CON_CAS c
 where c.est_solicitud='U'
 AND ROWNUM=1
 order by C.nro_referencia asc
 for update skip locked;

begin
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  g_lugar:= 'Recorre solicitudes';

  for i in con_cas loop
    v_nro_referencia:=i.nro_referencia;

      datoscas:=IT.typ_ObtConsDatosCas(i.nro_referencia,
                                    i.tip_identificador,
                                    i.val_identificador,
                                    i.cod_persona,
                                    i.tip_consulta,
                                    i.fecha,
                                    i.hora,
                                    i.est_solicitud);
       g_lugar:='Registro de parametros en log ';
      pas_cas.pr_reg_operacion(' Nro_referencia: '   ||i.nro_referencia   || chr(10) ||
                               ' Tip_identificador: '||i.Tip_identificador|| chr(10) ||
                               ' Val_identificador: '||i.Val_identificador|| chr(10) ||
                               ' Cod_persona: '      ||i.Cod_persona      || chr(10) ||
                               ' Tip_consulta: '     ||i.Tip_consulta     || chr(10) ||
                               ' Fecha: '            ||i.Fecha            || chr(10) ||
                               ' Hora: '             ||i.Hora             || chr(10) ||
                               ' Est_solicitud: '    ||i.Est_solicitud,
                               g_lugar||' Nro_referencia: '   ||i.nro_referencia );
  end loop;
 if v_nro_referencia is not null then

   g_lugar:='Asigna datos para la cabecera';
   p_dat_cab_cons_cas :=PAS_CAS.fu_obt_dat_Cab_concas(v_nro_referencia);

   g_lugar:='Actualizacion de consultas a bloqueado';
    begin

       UPDATE GE_SPI_CON_CAS
         SET Est_solicitud = 'B'
       WHERE nro_referencia = v_nro_referencia;

     if sql%rowcount > 0 then
      p_dat_cons_cas := datoscas;
      p_dat_mensaje   := mensaje;
     else
      mensaje.cod_respuesta := 1;
      mensaje.nom_respuesta := 'Error bloqueo';
      mensaje.des_Respuesta := 'No se pudo bloquear Registro';
      p_dat_cons_cas        := datoscas;
      p_dat_mensaje         := mensaje;
     end if;
    end;
     --commit;
 else
   mensaje.cod_respuesta := 2;
    mensaje.nom_respuesta := 'Sin registros';
    mensaje.des_Respuesta := 'No existe registro a consultar';
    p_dat_cons_cas        := datoscas;
    p_dat_mensaje         := mensaje;
 end if;
exception
  when others THEN
  mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Error';
    mensaje.des_Respuesta := 'Ocurrio un error al obtener la solicitud de consulta. '||SQLERRM;
    p_dat_mensaje         := mensaje;
 end pr_obt_concas;

procedure pr_pro_msj_rec_con_cas(p_res_concas in typ_ObtDatResCas,
                                 p_dat_mensaje out typ_mensajeria_spi) is

  v_nro_referencia GE_SPI_CON_CAS.nro_referencia%type;
  mensaje typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);

  v_desc_error varchar2(100);
begin
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;

  g_lugar := 'Registro de parametros en log';
  --Registro de parametros
  pas_cas.pr_reg_operacion('Parametros=> nro_referencia: ' ||
                           p_res_concas.nro_referencia || chr(10) ||
                           'tip_identificador: '     || p_res_concas.tip_identificador || chr(10) ||
                           'val_identificador: '     || p_res_concas.val_identificador || chr(10) ||
                           'cod_persona: '           || p_res_concas.cod_persona       || chr(10) ||
                           'tip_consulta: '          || p_res_concas.tip_consulta      || chr(10) ||
                           'fecha :'                 || p_res_concas.fecha             || chr(10) ||
                           'hora: '                  || p_res_concas.hora              || chr(10) ||
                           'val_cli_recordID: '      || p_res_concas.val_cli_recordID || chr(10) ||
                           'val_cta_recordID: '      ||  p_res_concas.val_cta_recordID || chr(10) ||
                           'val_alias_recordID: '    || p_res_concas.val_alias_recordID || chr(10) ||
                           'fec_vto_documento: '     || p_res_concas.fec_vto_documento || chr(10) ||
                           'nombre: '                || p_res_concas.nombre            || chr(10) ||
                           'apellido: '              || p_res_concas.apellido          || chr(10) ||
                           'nro_cuenta: '            || p_res_concas.nro_cuenta        || chr(10) ||
                           'tip_cuenta: '            ||  p_res_concas.tip_cuenta       || chr(10) ||
                           'cod_mon_cta: '           || p_res_concas.cod_mon_cta       ||  chr(10) ||
                           'fec_apertura: '          ||  p_res_concas.fec_apertura     || chr(10) ||
                           'fec_cancelacion: '       ||  p_res_concas.fec_cancelacion  || chr(10) ||
                           'cta_defecto: '           || p_res_concas.cta_defecto       || chr(10) ||
                           'error: '                 || p_res_concas.error             || chr(10) ||
                           'fec_registro: '          || p_res_concas.fec_registro      || chr(10) ||
                           'fec_venc_registro: '     || p_res_concas.fec_venc_registro || chr(10) ||
                           'cod_swi_participante: '  || p_res_concas.cod_swi_participante || chr(10) ||
                           'tip_doc_cliente: '       || p_res_concas.tip_doc_cliente || chr(10) ||
                           'nro_doc_cliente: '       || p_res_concas.nro_doc_cliente,
                           g_lugar|| ' nro_referencia: ' || p_res_concas.nro_referencia);
  /*se busca la referencia en GE_SPI_CON_CAS  para validar contra respuesta*/
  begin

    select nro_referencia
      into v_nro_referencia
      from GE_SPI_CON_CAS
     where nro_referencia = p_res_concas.nro_referencia ;
  EXCEPTION
    when no_data_found then
      v_nro_referencia := null;
    when too_many_rows  then
       g_lugar := 'Error al recuperar nro_referencia'||'-'|| p_res_concas.nro_referencia||'-'||v_nro_referencia||'-'||
       p_res_concas.tip_identificador||'-'||p_res_concas.val_identificador||'-'||p_res_concas.tip_consulta;
       mensaje.cod_respuesta := 1;
       mensaje.nom_respuesta := 'Error';
       mensaje.des_Respuesta := g_lugar;
       p_dat_mensaje         := mensaje;
  end;

  g_lugar := 'Referencia recibida contra enviada';
  if v_nro_referencia = p_res_concas.nro_referencia THEN

    IF UPPER(p_res_concas.tip_identificador) = fue_obt_val_max_referencia('TIP_IDE_CAS',p_res_concas.tip_identificador)  THEN

        --pas_spi.g_cod_error := 50;
          g_lugar             := 'indentificadores';

          if p_res_concas.error is not null THEN
           v_desc_error:=fue_obt_des_refcodes('TIP_REC_CAS',p_res_concas.error) ;
          else
            v_desc_error:= null;
          end if;

          begin
             g_lugar:= 'Inserta respuesta de consulta';
            insert into ge_spi_res_cas
                (nro_referencia, tip_identificador, val_identificador, cod_persona,
                 tip_consulta, fecha, hora, val_cli_recordid, val_cta_recordid, val_alias_recordid,
                 fec_vto_documento, nombre, apellido, nro_cuenta, tip_cuenta,
                 cod_mon_cta, fec_apertura, fec_cancelacion, cta_defecto, error,
                 fec_registro, fec_venc_registro,cod_swi_participante,
                 tip_doc_cliente,nro_doc_cliente)
              values
                (p_res_concas.nro_referencia, p_res_concas.tip_identificador, p_res_concas.val_identificador,
                 p_res_concas.cod_persona, p_res_concas.tip_consulta,p_res_concas.fecha,
                 p_res_concas.hora,p_res_concas.val_cli_recordID,p_res_concas.val_cta_recordID,
                 p_res_concas.val_alias_recordID,p_res_concas.fec_vto_documento,p_res_concas.nombre,
                 p_res_concas.apellido,p_res_concas.nro_cuenta,p_res_concas.tip_cuenta,p_res_concas.cod_mon_cta,
                 p_res_concas.fec_apertura,p_res_concas.fec_cancelacion,p_res_concas.cta_defecto,
                 v_desc_error,p_res_concas.fec_registro,p_res_concas.fec_venc_registro,p_res_concas.cod_swi_participante,
                 p_res_concas.tip_doc_cliente,p_res_concas.nro_doc_cliente);
              if sql%rowcount > 0 then
                 p_dat_mensaje         := mensaje;
              else
                mensaje.cod_respuesta := 3;
                mensaje.nom_respuesta := 'Error';
                mensaje.des_Respuesta := g_lugar;
                p_dat_mensaje         := mensaje;
              end if;
         end;
        g_lugar := 'actualiza GE_SPI_CON_CAS';
          /*actualiza GE_SPI_CON_CAS*/
        if p_res_concas.error is null then
          g_lugar:='error al actualizar GE_SPI_CON_CAS  ' ||v_nro_referencia;
            begin
                 UPDATE GE_SPI_CON_CAS
                 SET Est_solicitud = 'A'
                 WHERE nro_referencia = v_nro_referencia;

              if sql%rowcount > 0 then
               p_dat_mensaje         := mensaje;
              else
               mensaje.cod_respuesta := 4;
                mensaje.nom_respuesta := 'Error';
                mensaje.des_Respuesta := g_lugar;
                p_dat_mensaje         := mensaje;
              end if;
            end;
        ELSE
          g_lugar:='error al actualizar GE_SPI_CON_CAS con error '||v_nro_referencia;
            begin
             UPDATE GE_SPI_CON_CAS
              SET Est_solicitud = 'E'
              WHERE nro_referencia = v_nro_referencia;

              if sql%rowcount > 0 then
                p_dat_mensaje         := mensaje;
              else
                mensaje.cod_respuesta := 5;
                    mensaje.nom_respuesta := 'Error';
                    mensaje.des_Respuesta := g_lugar;
                    p_dat_mensaje         := mensaje;
              end if;

           end;
        end if;
    ELSE

      g_lugar             := 'tipo de indentificador no contemplado';
      mensaje.cod_respuesta := 2;
      mensaje.nom_respuesta := 'Error';
      mensaje.des_Respuesta := 'Error en '||g_lugar;
      p_dat_mensaje         := mensaje;
    end if;

  ELSE

    g_lugar := 'Referencia recibida distinta enviada'
    ||'-'|| p_res_concas.nro_referencia||'-'||v_nro_referencia||'-'||
    p_res_concas.tip_identificador||'-'||p_res_concas.val_identificador||'-'||p_res_concas.tip_consulta;

    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Error';
    mensaje.des_Respuesta := g_lugar;
    p_dat_mensaje         := mensaje;
  END IF;
exception
  when others THEN
  mensaje.cod_respuesta := 6;
    mensaje.nom_respuesta := 'Error';
    mensaje.des_Respuesta := 'Error en '||g_lugar||SQLERRM;
    p_dat_mensaje         := mensaje;
end pr_pro_msj_rec_con_cas;

procedure pr_ins_clie_cas(p_dat_cons_cas in out typ_obtregclicas,
                          P_CANAL        in varchar2,
                          p_accion       in varchar2 default null) is

  v_nro_referencia  GE_SPI_CON_CAS.nro_referencia%type;
  v_genero          varchar2(10);
  v_cod_persona     ba_personas.cod_persona%type;
  datosclie         typ_obtregclicas;
  v_cod_circuito    WF_TIP_CIRCUITOS.COD_TIP_CIRCUITO%type;
  v_residencia     ge_spi_cli_cas.residencia%type;
begin
  /*Inicializa las variables de error*/
  pas_cas.pr_ini_variables;

  /*se controla que el modulo cas este activo para generar las consultas*/
  if FUG_OBT_PARDINAMICO('HAB_SPI_CAS') = 'S' then
    v_nro_referencia:=pas_cas.fu_obt_sig_ref_cas;

    begin
          select p.cod_persona
            into V_cod_persona
            from ba_personas p
            where nro_documento= p_dat_cons_cas.val_identificador;
    end;

    if p_dat_cons_cas.genero ='M' then
      V_genero:=fue_obt_val_max_referencia('GEN_PER_CAS',p_dat_cons_cas.genero);
    elsif p_dat_cons_cas.genero = 'F' then
      V_genero:=fue_obt_val_max_referencia('GEN_PER_CAS',p_dat_cons_cas.genero);
    else
      V_genero := null;
    end if;

    if p_dat_cons_cas.tip_identificador <> 'RUC' and
       FUE_OBT_DES_PAIS(FUG_OBT_PAI_ENTIDAD) = p_dat_cons_cas.pais THEN
      v_residencia:= 'S';
    elsif  p_dat_cons_cas.tip_identificador <> 'RUC' and
           FUE_OBT_DES_PAIS(FUG_OBT_PAI_ENTIDAD) <> p_dat_cons_cas.pais then
      v_residencia:= 'N';
    elsif p_dat_cons_cas.tip_identificador = 'RUC' and
          FUE_OBT_DES_PAIS(FUG_OBT_PAI_ENTIDAD)= p_dat_cons_cas.pais then
      v_residencia:= null;
    END IF;

    begin
      insert into GE_SPI_CLI_CAS (nro_referencia,cli_recordid,tip_identificador,val_identificador,fec_vto_documento,
                                      residencia,nombre,apellido,apodo,genero,fec_nacimiento,lugar_nacimiento,direccion,
                                      pais,ciudad,departamento,inf_adicional,det_adicional_pv,est_cliente,est_solicitud,
                                      error,cod_persona,TIP_ACCION)
      values (v_nro_referencia,null,p_dat_cons_cas.tip_identificador,p_dat_cons_cas.val_identificador,
              p_dat_cons_cas.fec_vto_documento,v_residencia,p_dat_cons_cas.nombre,p_dat_cons_cas.apellido,p_dat_cons_cas.apodo,
              V_genero,p_dat_cons_cas.fec_nacimiento,p_dat_cons_cas.lugar_nacimiento,p_dat_cons_cas.direccion,p_dat_cons_cas.pais,
              p_dat_cons_cas.ciudad,p_dat_cons_cas.departamento,p_dat_cons_cas.inf_adicional,p_dat_cons_cas.det_adicional_pv,null,
               p_dat_cons_cas.est_solicitud,null,V_cod_persona,p_accion);

      if sql%rowcount > 0 then
        if P_CANAL is null then
          v_cod_circuito:= fug_obt_pardinamico('PAS_CAS_CIR_ALTA_CLI');
            if paw_cir.fu_ini_circuito( v_cod_circuito,v_nro_referencia, v_cod_persona ) <> 0 then
             --v_tit_mai_error := 'Error al intentar iniciar el circuito - SNP';
              pas_cas.g_cod_error := 50;
              pas_cas.g_msj_error := 'No se ha podido iniciar el circuito ' || 150 ||'. '|| nvl( paw_cir.fu_obt_msj_error, sqlerrm );
            else
              datosclie := typ_obtregclicas(v_nro_referencia,null,null,null,null,null,null,null,null,null,null,
              null,null,null,null,null,null,null,null,null,null);
              p_dat_cons_cas:= datosclie;
            end if;
        else
          datosclie := typ_obtregclicas();
          datosclie.nro_referencia:=v_nro_referencia;
          p_dat_cons_cas:= datosclie;
        end if;

      else
        pas_cas.g_msj_error := 'Error al registrar alta de cliente '||sqlerrm;
       pas_cas.g_cod_error := 1;
      end if;
   end;

  elsif  FUG_OBT_PARDINAMICO('HAB_SPI_CAS') = 'N' then
   /*si el parametro esta en N no genera ni una solicitud de consulta*/
    pas_cas.g_msj_error := 'El módulo CAS no se encuentra habilitado.';
    pas_cas.g_cod_error := 30;
  end if;
exception
  when others then
    pas_cas.g_msj_error := 'Error al registrar alta de cliente '||sqlerrm;
    pas_cas.g_cod_error := 1;

end pr_ins_clie_cas;

procedure pr_obt_dat_cli_cas (p_dat_cab_cons_cas out typ_obtdatcabconcas,
                               p_dat_cons_cas    out typ_obtregclicas,
                               p_dat_mensaje     out typ_mensajeria_spi) is

  v_nro_referencia  GE_SPI_CLI_CAS.nro_referencia%type:=null;
  datosclie         typ_obtregclicas;
  mensaje           typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);

 cursor alta_cli is
    select  c.nro_referencia,
            c.cli_recordid,
            c.tip_identificador,
            c.val_identificador,
            c.fec_vto_documento,
            c.residencia,
            c.nombre,
            c.apellido,
            c.apodo,
            c.genero,
            c.fec_nacimiento,
            c.lugar_nacimiento,
            c.direccion,
            c.pais,
            c.ciudad,
            c.departamento,
            c.inf_adicional,
            c.det_adicional_pv,
            c.est_cliente,
            c.est_solicitud,
            c.error,
            c.tip_accion
    from GE_SPI_CLI_CAS c
    where c.est_solicitud='U'
    AND ROWNUM=1
    order by C.nro_referencia asc
     for update skip locked;

begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    g_lugar:= 'Recorre solicitudes';

  for i in alta_cli loop
    v_nro_referencia:=i.nro_referencia;

    g_lugar:='Registro de parametros en log ';

    datosclie := it.typ_obtregclicas(i.nro_referencia,i.cli_recordid,i.tip_identificador,
                                      i.val_identificador,i.fec_vto_documento,i.residencia,
                                      i.nombre,i.apellido,i.apodo,i.genero,i.fec_nacimiento,
                                      i.lugar_nacimiento,i.direccion,i.pais,i.ciudad,i.departamento,
                                      i.inf_adicional,i.det_adicional_pv,i.est_cliente,i.est_solicitud,i.tip_accion);

     g_lugar:='Registro de parametros en log ';

     pas_cas.pr_reg_operacion('Nro_referencia: '     ||i.nro_referencia     || chr(10) ||
                              ' Cli_recordid: '      ||i.cli_recordid       || chr(10) ||
                              ' Tip_identificador: ' ||i.tip_identificador  || chr(10) ||
                              ' Val_identificador: ' ||i.val_identificador  || chr(10) ||
                              ' Fec_vto_documento: ' ||i.fec_vto_documento  || chr(10) ||
                              ' Residencia: '        ||i.residencia         || chr(10) ||
                              ' Nombre: '            ||i.nombre             || chr(10) ||
                              ' Apellido: '          ||i.apellido           || chr(10) ||
                              ' Apodo: '             ||i.apodo              || chr(10) ||
                              ' Genero: '            ||i.genero             || chr(10) ||
                              ' Fec_nacimiento: '    ||i.fec_nacimiento     || chr(10) ||
                              ' Lugar_nacimiento: '  ||i.lugar_nacimiento   || chr(10) ||
                              ' Direccion: '         ||i.direccion          || chr(10) ||
                              ' Pais: '              ||i.pais               || chr(10) ||
                              ' Ciudad: '            ||i.ciudad             || chr(10) ||
                              ' Departamento: '      ||i.departamento       || chr(10) ||
                              ' Inf_adicional: '     ||i.inf_adicional      || chr(10) ||
                              ' Det_adicional_pv: '  ||i.det_adicional_pv   || chr(10) ||
                              ' Est_cliente: '       ||i.est_cliente        || chr(10) ||
                              ' Est_solicitud: '     ||i.est_solicitud      || chr(10) ||
                              ' tip_accion: '        ||i.tip_accion,        g_lugar    ||
                              ' Nro_referencia: '   ||i.nro_referencia );

  end loop;

  if v_nro_referencia is not null then
    g_lugar:='Asigna datos para la cabecera';

    p_dat_cab_cons_cas :=PAS_CAS.fu_obt_dat_Cab_concas(v_nro_referencia);

    g_lugar:='Actualizacion de cliente a bloqueado';
     begin

         UPDATE GE_SPI_CLI_CAS
           SET Est_solicitud = 'B'
         WHERE nro_referencia = v_nro_referencia;

       if sql%rowcount > 0 then
         p_dat_cons_cas := datosclie;
         p_dat_mensaje   := mensaje;
       else
         mensaje.cod_respuesta := 1;
        mensaje.nom_respuesta := 'Error';
        mensaje.des_Respuesta := 'Error al bloquear registro.';
        p_dat_cons_cas        := datosclie;
        p_dat_mensaje         := mensaje;
       end if;
     end;
  else
    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Sin registros';
    mensaje.des_Respuesta := 'No existe registro a consultar';
    p_dat_cons_cas        := datosclie;
    p_dat_mensaje         := mensaje;
  end if;
exception
  when others then
    mensaje.cod_respuesta := 1;
        mensaje.nom_respuesta := 'Error';
        mensaje.des_Respuesta := 'Ocurrio un Error. '||sqlerrm;
        p_dat_cons_cas        := datosclie;
        p_dat_mensaje         := mensaje;

end pr_obt_dat_cli_cas;


 procedure pr_pro_msj_rec_cli_cas (p_dat_cons_cas     in typ_ObtDatResCli,
                                   p_dat_mensaje      out typ_mensajeria_spi) is

v_nro_referencia       GE_SPI_CLI_CAS.NRO_REFERENCIA%type;
v_nombre               GE_SPI_CLI_CAS.nombre%type;
v_apellido             GE_SPI_CLI_CAS.apellido%type;
v_est_cliente          GE_SPI_CLI_CAS.est_cliente%type;
v_tip_identificador    GE_SPI_CLI_CAS.tip_identificador%type;
v_val_identificador    GE_SPI_CLI_CAS.VAL_IDENTIFICADOR%type;
v_cli_recordid         ge_spi_cli_cas.cli_recordid%type;
v_fec_vto_documento    ge_spi_cli_cas.fec_vto_documento%type;
v_residencia           ge_spi_cli_cas.residencia%type;
v_apodo                ge_spi_cli_cas.apodo%type;
v_genero               ge_spi_cli_cas.genero%type;
v_fec_nacimiento       ge_spi_cli_cas.fec_nacimiento%type;
v_lugar_nacimiento     ge_spi_cli_cas.lugar_nacimiento%type;
v_direccion            ge_spi_cli_cas.direccion%type;
v_pais                 ge_spi_cli_cas.pais%type;
v_ciudad               ge_spi_cli_cas.ciudad%type;
v_departamento         ge_spi_cli_cas.departamento%type;
v_inf_adicional        ge_spi_cli_cas.inf_adicional%type;
v_det_adicional_pv     ge_spi_cli_cas.det_adicional_pv%type;
v_est_solicitud        ge_spi_cli_cas.est_solicitud%type;
v_tip_accion           ge_spi_cli_cas.tip_accion%type;

v_cod_persona          ba_personas.cod_persona%type;
mensaje                typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);
v_descripcion_error    varchar2(200);
v_inf_json             long:=null;

datosclie              typ_obtregclicas;
v_canal                varchar2(4);
begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;

    pas_cas.pr_ini_variables;
    g_lugar := 'Registro de parametros en log';
    --Registro de parametros
    pas_cas.pr_reg_operacion('Parametros=> Nro_referencia:' || p_dat_cons_cas.nro_referencia   || chr(10) ||
                             'Cli_recordID: '               ||p_dat_cons_cas.cli_recordID      || chr(10) ||
                             'Est_cliente: '                || p_dat_cons_cas.est_cliente      || chr(10) ||
                             'Error: '                      || p_dat_cons_cas.error            || chr(10) ||
                             'tip_accion: '                 || p_dat_cons_cas.tip_accion ,
                           g_lugar|| ' Nro_referencia: ' || p_dat_cons_cas.nro_referencia);

     /*se busca la referencia en ge_spi_cli_cas  para validar contra respuesta*/
      begin
        select c.nro_referencia, c.val_identificador
        into v_nro_referencia, v_val_identificador
        from ge_spi_cli_cas c
        where c.nro_referencia=p_dat_cons_cas.nro_referencia;
       exception
         when no_data_found then
         v_nro_referencia := null;
         v_val_identificador:= null;
         when others then
           g_lugar := 'Error al recuperar nro_referencia'||'-'|| p_dat_cons_cas.nro_referencia;
           mensaje.cod_respuesta := 1;
           mensaje.nom_respuesta := 'Error';
           mensaje.des_Respuesta := g_lugar;
           p_dat_mensaje         := mensaje;
      end;

    if v_nro_referencia = p_dat_cons_cas.nro_referencia then

       if p_dat_cons_cas.error is null then
         g_lugar := 'Actualizar ge_spi_cli_cas';

         begin
           update ge_spi_cli_cas c
           set c.cli_recordid    = p_dat_cons_cas.cli_recordID,
           c.est_cliente         = p_dat_cons_cas.est_cliente,
           c.est_solicitud       = 'A'
           where c.nro_referencia=p_dat_cons_cas.nro_referencia;

          if sql%rowcount > 0 then
                /*recupero datos de persona*/
              begin
                select p.cod_persona
                into v_cod_persona
                from ba_personas p
                where p.nro_documento=v_val_identificador;
              exception
                when no_data_found then
                  v_cod_persona := null;
                when others then
                 v_cod_persona := null;
               end;

              begin
                 select nro_referencia, cli_recordid, tip_identificador, val_identificador,
                        fec_vto_documento, residencia, nombre, apellido, apodo ,genero, fec_nacimiento,
                        lugar_nacimiento, direccion, pais, ciudad, departamento, inf_adicional,
                        det_adicional_pv, est_cliente, est_solicitud, tip_accion

                 into v_nro_referencia, v_cli_recordid, v_tip_identificador, v_val_identificador,
                      v_fec_vto_documento, v_residencia, v_nombre, v_apellido, v_apodo, v_genero, v_fec_nacimiento,
                      v_lugar_nacimiento,v_direccion,v_pais,v_ciudad,v_departamento,v_inf_adicional,
                      v_det_adicional_pv,v_est_cliente,v_est_solicitud,v_tip_accion

                 from GE_SPI_CLI_CAS c
                 where c.nro_referencia = p_dat_cons_cas.nro_referencia;
                exception
                  when no_data_found then
                    v_tip_identificador    := null;
                    v_val_identificador    := null;
                    v_nombre               := null;
                    v_apellido             := null;
                    v_est_cliente          := null;
                  when others then
                    v_tip_identificador    := null;
                    v_val_identificador    := null;
                    v_nombre               := null;
                    v_apellido             := null;
                    v_est_cliente          := null;
               end;

              v_inf_json:='{'||'"tip_documento":'   ||'"'||v_tip_identificador ||'"'||','||
                               '"nro_documento":'   ||'"'||v_val_identificador ||'"'||','||
                               '"nombre":'          ||'"'||v_nombre            ||'"'||','||
                               '"apellido":'        ||'"'||v_apellido          ||'"'||','||
                               '"est_cliente":'     ||'"'||v_est_cliente       ||'"' || '}';

               if p_dat_cons_cas.tip_accion is null  then

                  if fu_obt_tip_per(v_cod_persona) = 'F' then
                        pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTCLCAS'),v_inf_json);
                        p_dat_mensaje := mensaje;
                  elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                      pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTCLCASPJ'),v_inf_json);
                      p_dat_mensaje         := mensaje;
                  else
                      p_dat_mensaje         := mensaje;
                  end if;

               elsif p_dat_cons_cas.tip_accion= 'E' or  p_dat_cons_cas.tip_accion= 'A'  then
                /* se recuper datos del cliente y se llama al procedure pr_edi_clie_cas
                de edicion para activar  al cliente */

                  datosclie := typ_obtregclicas(v_nro_referencia,v_cli_recordid,v_tip_identificador,v_val_identificador,
                        v_fec_vto_documento,v_residencia,v_nombre,v_apellido,v_apodo,v_genero,v_fec_nacimiento,
                        v_lugar_nacimiento,v_direccion,v_pais,v_ciudad,v_departamento,v_inf_adicional,
                        v_det_adicional_pv,v_est_cliente,v_est_solicitud,v_tip_accion);

                   if p_dat_cons_cas.tip_accion = 'E'  THEN
                      v_canal := 'WEBE';
                   ELSIF  p_dat_cons_cas.tip_accion = 'A' THEN
                      v_canal := 'WEBA';
                   END IF;

                  pas_cas.pr_edi_clie_cas( datosclie,'ACT',v_canal);
               else
                p_dat_mensaje := mensaje;
               end if;
           else
              mensaje.cod_respuesta := 3;
              mensaje.nom_respuesta := 'Error';
              mensaje.des_Respuesta := g_lugar;
              p_dat_mensaje         := mensaje;
           end if;
         end;
       else
         /*buscamos la descripcion del error*/
         v_descripcion_error := fue_obt_des_refcodes('TIP_REC_CAS',p_dat_cons_cas.error) ;
          g_lugar := 'Actualizar ge_spi_cli_cas';
          begin

              update ge_spi_cli_cas c
               set c.est_solicitud       = 'E',
                   c.error                 = p_dat_cons_cas.error||' '||v_descripcion_error
               where c.nro_referencia=p_dat_cons_cas.nro_referencia;
               if sql%rowcount > 0 then
                   begin
                    select p.cod_persona
                    into v_cod_persona
                    from ba_personas p
                    where p.nro_documento=v_val_identificador;
                   exception
                     when no_data_found then
                       v_cod_persona := null;
                   end;

                   begin
                      select c.tip_identificador,c.val_identificador,c.nombre,
                                c.apellido,c.est_cliente

                         into v_tip_identificador,v_val_identificador,v_nombre,
                              v_apellido,v_est_cliente

                         from GE_SPI_CLI_CAS c
                         where c.nro_referencia = p_dat_cons_cas.nro_referencia;
                  exception
                   when no_data_found then
                        v_tip_identificador    := null;
                        v_val_identificador    := null;
                        v_nombre               := null;
                        v_apellido             := null;
                        v_est_cliente          := null;
                  end;
                  v_inf_json:='{'||'"tip_documento":'   ||'"'||v_tip_identificador ||'"'||','||
                                   '"nro_documento":'   ||'"'||v_val_identificador ||'"'||','||
                                   '"nombre":'          ||'"'||v_nombre            ||'"'||','||
                                   '"apellido":'        ||'"'||v_apellido          ||'"'||','||
                                   '"est_cliente":'     ||'"'||v_est_cliente       ||'"'||','||
                                   '"error":'           ||'"'||v_descripcion_error ||'"'||'}';

                  if p_dat_cons_cas.tip_accion is null  then
                       if fu_obt_tip_per(v_cod_persona) = 'F' then
                            pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTCLNCAS'),v_inf_json);
                            p_dat_mensaje         := mensaje;
                      elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                          pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTCLNCASPJ'),v_inf_json);
                          p_dat_mensaje         := mensaje;
                      else
                            p_dat_mensaje         := mensaje;
                      end if;
                  elsif p_dat_cons_cas.tip_accion='E' or  p_dat_cons_cas.tip_accion='A'  then
                    /*las notificaciones por alta o edicion desde la web se generan al dar alta el alias*/
                        p_dat_mensaje         := mensaje;
                  end if;
               else
                mensaje.cod_respuesta := 3;
                mensaje.nom_respuesta := 'Error';
                mensaje.des_Respuesta := g_lugar;
                p_dat_mensaje         := mensaje;
               end if;
          end;
       end IF;
    else
      g_lugar := 'Referencia recibida distinta enviada' ||
      '- Recibida: '|| p_dat_cons_cas.nro_referencia||
      '- Buscada: '||v_nro_referencia;

      mensaje.cod_respuesta := 2;
      mensaje.nom_respuesta := 'Error';
      mensaje.des_Respuesta := g_lugar;
      p_dat_mensaje         := mensaje;
    end if;
exception
  when others then
      mensaje.cod_respuesta := 2;
      mensaje.nom_respuesta := 'Error';
      mensaje.des_Respuesta := 'Ocurrio un error. '||sqlerrm;
      p_dat_mensaje         := mensaje;
end pr_pro_msj_rec_cli_cas;
procedure pr_edi_clie_cas(p_dat_cons_cas in out typ_obtregclicas,
                          p_accion       in varchar2,
                          p_canal       in varchar2 default null) is
  v_nro_referencia  GE_SPI_CON_CAS.nro_referencia%type;
  v_genero           varchar2(10);
  v_cod_persona      ba_personas.cod_persona%type;
  v_tip_acccion      varchar(20);
  v_est_solicitud    varchar(1);
  datosclie          typ_obtregclicas;
  v_cod_circuito     WF_TIP_CIRCUITOS.COD_TIP_CIRCUITO%type;
begin
  /*se controla que el modulo cas este activo para generar las consultas*/
  if FUG_OBT_PARDINAMICO('HAB_SPI_CAS') = 'S' then
     v_nro_referencia:=pas_cas.fu_obt_sig_ref_cas;

    if p_accion ='EDI' THEN
       v_tip_acccion:='Edición';
     elsif p_accion ='SUS' THEN
        v_tip_acccion:='Suspensión';
     elsif p_accion ='ACT' THEN
        v_tip_acccion:='Activación';
     elsif p_accion ='ELI'THEN
        v_tip_acccion:='Eliminación';
     END IF;

    if p_dat_cons_cas.genero ='M' then
      V_genero:=fue_obt_val_max_referencia('GEN_PER_CAS',p_dat_cons_cas.genero);
    elsif p_dat_cons_cas.genero = 'F' then
      V_genero:=fue_obt_val_max_referencia('GEN_PER_CAS',p_dat_cons_cas.genero);
    else
      V_genero := null;
    end if;

    if p_canal is null then
      /*viende desde itgf*/
      v_est_solicitud := 'P';
    else
      /*viende desde web*/
      v_est_solicitud := 'U';
    end if;

    begin
        insert into GE_SPI_CLI_CAS_TMP (nro_referencia,cli_recordid,tip_identificador,val_identificador,fec_vto_documento,
                                      residencia,nombre,apellido,apodo,genero,fec_nacimiento,lugar_nacimiento,direccion,
                                      pais,ciudad,departamento,inf_adicional,det_adicional_pv,est_cliente,est_solicitud,
                                      error,tip_Accion,TIP_CANAL)
        values (v_nro_referencia,p_dat_cons_cas.cli_recordID,p_dat_cons_cas.tip_identificador,p_dat_cons_cas.val_identificador,
                p_dat_cons_cas.fec_vto_documento,p_dat_cons_cas.residencia,p_dat_cons_cas.nombre,p_dat_cons_cas.apellido,p_dat_cons_cas.apodo,
                V_genero,p_dat_cons_cas.fec_nacimiento,p_dat_cons_cas.lugar_nacimiento,p_dat_cons_cas.direccion,p_dat_cons_cas.pais,
                p_dat_cons_cas.ciudad,p_dat_cons_cas.departamento,p_dat_cons_cas.inf_adicional,p_dat_cons_cas.det_adicional_pv,p_dat_cons_cas.est_cliente,
                v_est_solicitud,null,p_accion,p_canal);

       if sql%rowcount > 0 then
            begin
                select p.cod_persona
                  into V_cod_persona
                  from ba_personas p
                  where nro_documento=p_dat_cons_cas.val_identificador;
            exception
             when no_data_found then
                 V_cod_persona := null;
              when others then
                 V_cod_persona := null;
            end;
           if p_canal is null then
                IF p_accion ='EDI' THEN
                  v_cod_circuito:= fug_obt_pardinamico('PAS_CAS_CIR_EDI_CLI');
                    if paw_cir.fu_ini_circuito( v_cod_circuito,v_nro_referencia, v_cod_persona ) <> 0 then

                      pas_cas.g_cod_error := 50;
                      pas_cas.g_msj_error := 'No se ha podido iniciar el circuito ' || 151 ||'. '|| nvl( paw_cir.fu_obt_msj_error, sqlerrm );
                    else
                      datosclie := typ_obtregclicas(v_nro_referencia,null,null,null,null,null,null,
                      null,null,null,null,null,null,null,null,null,null,null,null,null,null);
                      p_dat_cons_cas := datosclie;
                    end if;
                ELSIF p_accion ='SUS' THEN
                   v_cod_circuito:= fug_obt_pardinamico('PAS_CAS_CIR_SUS_CLI');
                     if paw_cir.fu_ini_circuito( v_cod_circuito,v_nro_referencia, v_cod_persona ) <> 0 then
                      pas_cas.g_cod_error := 50;
                      pas_cas.g_msj_error := 'No se ha podido iniciar el circuito ' || 152 ||'. '|| nvl( paw_cir.fu_obt_msj_error, sqlerrm );
                    else
                        datosclie := typ_obtregclicas(v_nro_referencia,null,null,null,null,null,null,
                        null,null,null,null,null,null,null,null,null,null,null,null,null,null);
                        p_dat_cons_cas := datosclie;
                      end if;
                ELSIF p_accion ='ACT' THEN
                  v_cod_circuito:= fug_obt_pardinamico('PAS_CAS_CIR_ACTI_CLI');
                     if paw_cir.fu_ini_circuito( v_cod_circuito,v_nro_referencia, v_cod_persona ) <> 0 then
                      pas_cas.g_cod_error := 50;
                      pas_cas.g_msj_error := 'No se ha podido iniciar el circuito ' || 153 ||'. '|| nvl( paw_cir.fu_obt_msj_error, sqlerrm );
                    else
                      datosclie := typ_obtregclicas(v_nro_referencia,null,null,null,null,null,null,
                      null,null,null,null,null,null,null,null,null,null,null,null,null,null);
                      p_dat_cons_cas := datosclie;
                    end if;
                ELSIF p_accion ='ELI' THEN
                  v_cod_circuito:= fug_obt_pardinamico('PAS_CAS_CIR_ELI_CLI');
                     if paw_cir.fu_ini_circuito( v_cod_circuito,v_nro_referencia, v_cod_persona ) <> 0 then
                      pas_cas.g_cod_error := 50;
                      pas_cas.g_msj_error := 'No se ha podido iniciar el circuito ' || 151 ||'. '|| nvl( paw_cir.fu_obt_msj_error, sqlerrm );
                    else
                      datosclie := typ_obtregclicas(v_nro_referencia,null,null,null,null,null,null,
                      null,null,null,null,null,null,null,null,null,null,null,null,null,null);
                      p_dat_cons_cas := datosclie;
                    end if;
                END IF;
           end if;
       else
          pas_cas.g_msj_error := 'Error al registrar la '||v_tip_acccion||'del cliente '||sqlerrm;
          pas_cas.g_cod_error := 1;
      end if;

     end;

  elsif  FUG_OBT_PARDINAMICO('HAB_SPI_CAS') = 'N' then
   /*si el parametro esta en N no genera ni una solicitud de consulta*/
    pas_cas.g_msj_error := 'El módulo CAS no se encuentra habilitado.';
    pas_cas.g_cod_error := 30;
  end if;
 Exception
   when others then
     pas_cas.g_msj_error := 'Ocurrio un error. '||sqlerrm;
     pas_cas.g_cod_error := 1;
end pr_edi_clie_cas;

procedure pr_obt_edi_cli_cas(p_dat_cab_cons_cas out typ_ObtdatCabconcas ,
                             p_dat_cons_cas     out typ_ObtEdiclicas,
                             p_dat_mensaje      out typ_mensajeria_spi) is

v_nro_referencia  ge_spi_cli_cas_tmp.nro_referencia%type:=null;
v_tip_accion      ge_spi_cli_cas_tmp.tip_accion%type:=null;
datosclie         typ_ObtEdiclicas;
mensaje           typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);


cursor edi_cli is
    select  nro_referencia,
            cli_recordID,
            est_cliente,
            fec_vto_documento,
            apodo,
            inf_adicional,
            det_adicional_pv,
            c.tip_accion,
            c.tip_canal
    from GE_SPI_CLI_CAS_tMP c
    where c.est_solicitud='U'
    AND ROWNUM=1
    order by C.nro_referencia asc
     for update skip locked;
begin
     begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;

    g_lugar := 'Recorremos registros';
    for i in  edi_cli loop
     v_nro_referencia:= i.nro_referencia;
     v_tip_accion:=i.tip_accion;

     datosclie:= typ_ObtEdiclicas( i.nro_referencia,
                                   i.cli_recordID,
                                   i.est_cliente,
                                   i.fec_vto_documento,
                                   i.apodo,
                                   i.inf_adicional, i.det_adicional_pv,i.tip_accion,null,i.tip_canal);

       g_lugar:='Registro de parametros en log ';
        pas_cas.pr_reg_operacion('Nro_referencia: '  ||i.nro_referencia     || chr(10) ||
                              ' Cli_recordid: '      ||i.cli_recordid       || chr(10) ||
                              ' Estado_cliente: '    ||i.est_cliente        || chr(10) ||
                              ' Fec_vto_documento: ' ||i.fec_vto_documento  || chr(10) ||
                              ' Apodo: '             ||i.apodo              || chr(10) ||
                              ' Inf_adicional: '     ||i.inf_adicional      || chr(10) ||
                              ' Det_adicional_pv: '  ||i.det_adicional_pv   || chr(10) ||
                              ' Tipo_accion: '       ||i.tip_accion         || chr(10) ||
                              ' Tip_canal: '         ||i.tip_canal          ,g_lugar    ||
                              ' Nro_referencia: '   ||i.nro_referencia );
    end loop ;
    if  v_nro_referencia is not null then
      g_lugar:='Asigna datos para la cabecera';
      p_dat_cab_cons_cas :=PAS_CAS.fu_obt_dat_Cab_concas(v_nro_referencia);

      g_lugar:='Actualizacion de cliente a bloqueado';
      begin

         UPDATE ge_spi_cli_cas_tmp
         SET Est_solicitud = 'B'
         WHERE nro_referencia = v_nro_referencia
         and tip_accion=v_tip_accion;

       if sql%rowcount > 0 then
         p_dat_cons_cas := datosclie;
         p_dat_mensaje   := mensaje;
       else
          mensaje.cod_respuesta := 2;
          mensaje.nom_respuesta := 'Error';
          mensaje.des_Respuesta := 'Error al bloquear Registro';
          p_dat_cons_cas        := datosclie;
          p_dat_mensaje         := mensaje;
        end if;
       end;
    else
       mensaje.cod_respuesta := 1;
      mensaje.nom_respuesta := 'Sin registros';
      mensaje.des_Respuesta := 'No existe registro a consultar';
      p_dat_cons_cas        := datosclie;
      p_dat_mensaje         := mensaje;
    end if;
exception
  when others then
    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Error';
    mensaje.des_Respuesta := 'Ocurrio un error. '|| sqlerrm;
    p_dat_cons_cas        := datosclie;
    p_dat_mensaje         := mensaje;
end pr_obt_edi_cli_cas;

procedure pr_pro_msj_rec_edi_cas(p_dat_cons_cas     in typ_ObtEdiclicas,
                                 p_dat_mensaje     out typ_mensajeria_spi)is

 mensaje               typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);
 v_nro_referencia       GE_SPI_CLI_CAS_tmp.NRO_REFERENCIA%type;
 v_tip_identificador    GE_SPI_CLI_CAS_tmp.tip_identificador%type;
 v_val_identificador    GE_SPI_CLI_CAS_tmp.VAL_IDENTIFICADOR%type;
 v_nombre               GE_SPI_CLI_CAS_tmp.nombre%type;
 v_apellido             ge_spi_cli_cas_tmp.apellido%type;
 v_est_cliente           GE_SPI_CLI_CAS_tmp.est_cliente%type;
 v_cod_persona           ba_personas.cod_persona%type;

 v_descripcion_error     varchar2(100);
 v_inf_json              long:=null;

begin
  begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;

  pas_cas.pr_ini_variables;
    g_lugar := 'Registro de parametros en log';
    --Registro de parametros

    pas_cas.pr_reg_operacion('Nro_referencia: '      ||p_dat_cons_cas.nro_referencia     || chr(10) ||
                              ' Cli_recordid: '      ||p_dat_cons_cas.cli_recordid       || chr(10) ||
                              ' Estado_cliente: '    ||p_dat_cons_cas.est_cliente        || chr(10) ||
                              ' Fec_vto_documento: ' ||p_dat_cons_cas.fec_vto_documento  || chr(10) ||
                              ' Apodo: '             ||p_dat_cons_cas.apodo              || chr(10) ||
                              ' Inf_adicional: '     ||p_dat_cons_cas.inf_adicional      || chr(10) ||
                              ' Det_adicional_pv: '  ||p_dat_cons_cas.det_adicional_pv   || chr(10) ||
                              ' Tipo_accion: '       ||p_dat_cons_cas.tip_edicion        || chr(10) ||
                              ' Error: '             ||p_dat_cons_cas.error              || chr(10) ||
                              ' Tip_Canal: '         ||p_dat_cons_cas.tip_canal,
                               g_lugar||' Nro_referencia: '   ||p_dat_cons_cas.nro_referencia );

   /*se busca la referencia en ge_spi_cli_cas  para validar contra respuesta*/
      begin
        select c.nro_referencia, c.tip_identificador, c.val_identificador,
               c.nombre,c.apellido

        into v_nro_referencia,v_tip_identificador ,v_val_identificador,
             v_nombre,v_apellido

        from ge_spi_cli_cas_tmp c

        where c.nro_referencia=p_dat_cons_cas.nro_referencia
        and c.tip_accion=p_dat_cons_cas.tip_edicion;
       exception
         when no_data_found then
         v_nro_referencia        := null;
         v_val_identificador     := null;
         when others then
           g_lugar := 'Error al recuperar nro_referencia'||'-'|| p_dat_cons_cas.nro_referencia;
           mensaje.cod_respuesta := 1;
           mensaje.nom_respuesta := 'Error';
           mensaje.des_Respuesta := g_lugar;
           p_dat_mensaje         := mensaje;
      end;

  if  v_nro_referencia =  p_dat_cons_cas.nro_referencia then

        if p_dat_cons_cas.tip_edicion = 'EDI' THEN
           if p_dat_cons_cas.error is null then
              begin
                 g_lugar := 'Actualizar ge_spi_cli_cas_temp';

                 update ge_spi_cli_cas_tmp c
                 set c.est_solicitud       = 'A'
                 where c.nro_referencia= p_dat_cons_cas.nro_referencia;
                  if sql%rowcount > 0 then
                     begin
                       g_lugar := 'Actualizar ge_spi_cli_cas';

                       update ge_spi_cli_cas c
                       set fec_vto_documento = p_dat_cons_cas.fec_vto_documento,
                           apodo             = p_dat_cons_cas.apodo,
                           inf_adicional     = p_dat_cons_cas.inf_adicional,
                           det_adicional_pv  = p_dat_cons_cas.det_adicional_pv
                        where c.tip_identificador = v_tip_identificador
                        and c.val_identificador   = v_val_identificador
                        and c.cli_recordid          = p_dat_cons_cas.cli_recordID;

                       if sql%rowcount > 0 then
                          begin
                            select p.cod_persona
                            into v_cod_persona
                            from ba_personas p
                            where p.nro_documento=v_val_identificador;
                          exception
                            when no_data_found then
                              v_cod_persona := null;
                           end;

                          v_inf_json:='{'||'"nombre":'           ||'"'||FUE_OBT_NOM_PERSONA(v_cod_persona) ||'"'||','||
                                           '"tip_documento":'    ||'"'||v_tip_identificador                ||'"'||','||
                                           '"nro_documento":'    ||'"'||v_val_identificador                ||'"'||','||
                                           '"fec_ven_doc":'      ||'"'||to_char(p_dat_cons_cas.fec_vto_documento, 'DD/MM/YYYY')   ||'"'||','||
                                           '"apodo":'            ||'"'|| p_dat_cons_cas.apodo              ||'"'||','||
                                           '"info_adicional":'   ||'"'|| p_dat_cons_cas.inf_adicional      ||'"'||','||
                                           '"det_adicional":'    ||'"'|| p_dat_cons_cas. det_adicional_pv  ||'"'|| '}';
                                 if  p_dat_cons_cas.tip_canal is null then
                                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                                               pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTEDCLCAS'),v_inf_json);
                                               p_dat_mensaje         := mensaje;
                                           elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                                             pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTEDCLCASPJ'),v_inf_json);
                                             p_dat_mensaje         := mensaje;
                                           else
                                             p_dat_mensaje         := mensaje;
                                           end if;
                                 elsif p_dat_cons_cas.tip_canal = 'WEBA' then
                                         /*se genera la notificacion de alta en un solo paso al finalizar el alta de alias*/
                                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                                             p_dat_mensaje         := mensaje;
                                         elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                                             p_dat_mensaje         := mensaje;
                                         else
                                            p_dat_mensaje         := mensaje;
                                         end if;
                                 elsif p_dat_cons_cas.tip_canal = 'WEBE' then
                                          /*se genera la notificacion de Edicion en un solo paso al finalizar el alta de alias*/
                                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                                              p_dat_mensaje         := mensaje;
                                          elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                                             p_dat_mensaje         := mensaje;
                                          else
                                             p_dat_mensaje         := mensaje;
                                          end if;
                                 end if;

                       else
                        mensaje.cod_respuesta := 3;
                         mensaje.nom_respuesta := 'Error';
                         mensaje.des_Respuesta := g_lugar;
                         p_dat_mensaje         := mensaje;
                        end if;
                     end ;
                  else
                       mensaje.cod_respuesta := 4;
                       mensaje.nom_respuesta := 'Error';
                       mensaje.des_Respuesta := g_lugar;
                       p_dat_mensaje         := mensaje;
                  end if;
              end;
           else

            /*buscamos la descripcion del error*/
            v_descripcion_error:=fue_obt_des_refcodes('TIP_REC_CAS',p_dat_cons_cas.error) ;


               g_lugar := 'Actualizar ge_spi_cli_cas_temp';
               begin
                 update ge_spi_cli_cas_tmp c
                 set c.est_solicitud   = 'E',
                     c.error           = p_dat_cons_cas.error||' '||v_descripcion_error
                 where c.nro_referencia = p_dat_cons_cas.nro_referencia;

                 if sql%rowcount > 0 then
                   /*recupero datos de persona*/
                    begin
                      select p.cod_persona
                      into v_cod_persona
                      from ba_personas p
                      where p.nro_documento=v_val_identificador;
                     end;

                    v_inf_json:='{'||'"nombre":'          ||'"'||FUE_OBT_NOM_PERSONA(v_cod_persona) ||'"'||','||
                                     '"tip_documento":'   ||'"'||v_tip_identificador ||'"'||','||
                                     '"nro_documento":'   ||'"'||v_val_identificador ||'"'||','||
                                     '"fec_ven_doc":'     ||'"'|| to_char(p_dat_cons_cas.fec_vto_documento, 'DD/MM/YYYY')  ||'"'||','||
                                     '"apodo":'           ||'"'|| p_dat_cons_cas.apodo              ||'"'||','||
                                     '"info_adicional":'  ||'"'|| p_dat_cons_cas.inf_adicional      ||'"'||','||
                                     '"det_adicional":'   ||'"'|| p_dat_cons_cas. det_adicional_pv  ||'"'|| '}';

                      if  p_dat_cons_cas.tip_canal is null then
                                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                                                pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTEDNCCAS'),v_inf_json);
                                                p_dat_mensaje         := mensaje;
                                           elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                                             pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTEDNCCASPJ'),v_inf_json);
                                             p_dat_mensaje         := mensaje;
                                           else
                                             p_dat_mensaje         := mensaje;
                                           end if;
                      elsif p_dat_cons_cas.tip_canal = 'WEBA' then
                                         /*se genera la notificacion de alta en un solo paso al finalizar el alta de alias*/
                                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                                             p_dat_mensaje         := mensaje;
                                         elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                                             p_dat_mensaje         := mensaje;
                                         else
                                            p_dat_mensaje         := mensaje;
                                         end if;
                      elsif p_dat_cons_cas.tip_canal = 'WEBE' then
                                          /*se genera la notificacion de Edicion en un solo paso al finalizar el alta de alias*/
                                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                                              p_dat_mensaje         := mensaje;
                                          elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                                             p_dat_mensaje         := mensaje;
                                          else
                                             p_dat_mensaje         := mensaje;
                                          end if;
                     end if;
                else
                  mensaje.cod_respuesta := 3;
                  mensaje.nom_respuesta := 'Error';
                  mensaje.des_Respuesta := g_lugar;
                  p_dat_mensaje         := mensaje;
                 end if;
               end;

           end if;
        ELSIF  p_dat_cons_cas.tip_edicion = 'SUS' THEN
           If p_dat_cons_cas.error is null then

               g_lugar := 'Actualizar ge_spi_cli_cas_tmp';
               begin

                   update ge_spi_cli_cas_tmp t
                   set est_solicitud='A'
                   where nro_referencia = p_dat_cons_cas.nro_referencia
                   and tip_accion=p_dat_cons_cas.tip_edicion;

                   if sql%rowcount > 0 then
                       g_lugar := 'Actualizar ge_spi_cli_cas';
                       begin

                          update ge_spi_cli_cas
                          set est_cliente= p_dat_cons_cas.est_cliente
                          where tip_identificador = v_tip_identificador
                          and val_identificador   = v_val_identificador
                          and cli_recordid        = p_dat_cons_cas.cli_recordID  ;

                         if sql%rowcount > 0 then
                          begin
                            select p.cod_persona
                            into v_cod_persona
                            from ba_personas p
                            where p.nro_documento=v_val_identificador;
                           exception
                           when others then
                             v_cod_persona := null;
                           end;

                            v_inf_json:='{'||'"tip_documento":'         ||'"'||v_tip_identificador ||'"'||','||
                                             '"nro_documento":'         ||'"'||v_val_identificador ||'"'||','||
                                             '"nombre":'                ||'"'||v_nombre            ||'"'||','||
                                             '"apellido":'              ||'"'||v_apellido          ||'"'||','||
                                             '"est_cliente":'           ||'"'||p_dat_cons_cas.est_cliente      ||'"'|| '}';
                                  if  p_dat_cons_cas.tip_canal is null then
                                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                                              pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTSUSCCAS'),v_inf_json);
                                              p_dat_mensaje         := mensaje;
                                           elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                                             pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTSUSCCASPJ'),v_inf_json);
                                             p_dat_mensaje         := mensaje;
                                           else
                                             p_dat_mensaje         := mensaje;
                                           end if;
                                 elsif p_dat_cons_cas.tip_canal = 'WEBA' then
                                         /*se genera la notificacion de alta en un solo paso*/
                                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                                             null;
                                         elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                                             null;
                                         else
                                            null;
                                         end if;
                                 elsif p_dat_cons_cas.tip_canal = 'WEBE' then
                                          /*se genera la notificacion de edicion en un solo paso*/
                                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                                              p_dat_mensaje         := mensaje;
                                              null;
                                          elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                                             null;
                                             p_dat_mensaje         := mensaje;
                                          else
                                             p_dat_mensaje         := mensaje;
                                          end if;
                                 end if;
                           else
                           mensaje.cod_respuesta := 5;
                           mensaje.nom_respuesta := 'Error';
                           mensaje.des_Respuesta := g_lugar;
                           p_dat_mensaje         := mensaje;
                           end if;
                       end ;

                   else
                      mensaje.cod_respuesta := 4;
                       mensaje.nom_respuesta := 'Error';
                       mensaje.des_Respuesta := g_lugar;
                       p_dat_mensaje         := mensaje;
                   end if;
               end;

          else

                /*buscamos la descripcion del error*/
                 v_descripcion_error:=fue_obt_des_refcodes('TIP_REC_CAS',p_dat_cons_cas.error) ;
               g_lugar := 'Actualizar ge_spi_cli_cas_temp';
              begin
                 update ge_spi_cli_cas_tmp c
                 set c.est_solicitud       = 'E',
                  c.error                 = p_dat_cons_cas.error||' '||v_descripcion_error
                  where c.nro_referencia=p_dat_cons_cas.nro_referencia;
                if sql%rowcount > 0 then
                  begin
                      select p.cod_persona
                      into v_cod_persona
                      from ba_personas p
                      where p.nro_documento=v_val_identificador;
                  exception
                  when others THEN
                  v_cod_persona:= null;
                  end;

                   v_inf_json:='{'||'"tip_documento":'   ||'"'||v_tip_identificador        ||'"'||','||
                                    '"nro_documento":'   ||'"'||v_val_identificador        ||'"'||','||
                                    '"nombre":'          ||'"'||v_nombre                   ||'"'||','||
                                    '"apellido":'        ||'"'||v_apellido                 ||'"'||','||
                                    '"est_cliente":'     ||'"'||p_dat_cons_cas.est_cliente ||'"'||','||
                                    '"error":'           ||'"'||v_descripcion_error        ||'"'|| '}';


                         if  p_dat_cons_cas.tip_canal is null then
                                 if fu_obt_tip_per(v_cod_persona) = 'F' then
                                      pas_spi.pr_env_alerta(v_cod_persona,
                                      fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTNSUSCAS'),v_inf_json);
                                      p_dat_mensaje         := mensaje;
                                   elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                                     pas_spi.pr_env_alerta(v_cod_persona,
                                      fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTSUSNCASPJ'),v_inf_json);
                                     p_dat_mensaje         := mensaje;
                                   else
                                     p_dat_mensaje         := mensaje;
                                   end if;
                         elsif p_dat_cons_cas.tip_canal = 'WEBA' then
                                 /*se genera la notificacion de alta en un solo paso*/
                                 if fu_obt_tip_per(v_cod_persona) = 'F' then
                                      p_dat_mensaje         := mensaje;
                                 elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                                      p_dat_mensaje         := mensaje;
                                 else
                                     p_dat_mensaje         := mensaje;
                                 end if;
                         elsif p_dat_cons_cas.tip_canal = 'WEBE' then
                                  /*se genera la notificacion de edicion en un solo paso*/
                                 if fu_obt_tip_per(v_cod_persona) = 'F' then
                                      p_dat_mensaje         := mensaje;
                                  elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                                     p_dat_mensaje         := mensaje;
                                  else
                                     p_dat_mensaje         := mensaje;
                                  end if;
                         end if;
                else
                  mensaje.cod_respuesta := 6;
                  mensaje.nom_respuesta := 'Error';
                  mensaje.des_Respuesta := g_lugar;
                  p_dat_mensaje         := mensaje;
                end if;
              end;
         end if;
        ELSIF  p_dat_cons_cas.tip_edicion = 'ACT' THEN
           If p_dat_cons_cas.error is null then

               g_lugar := 'Actualizar ge_spi_cli_cas_tmp';
               begin
                   update ge_spi_cli_cas_tmp t
                   set est_solicitud='A'
                   where nro_referencia = p_dat_cons_cas.nro_referencia
                    and tip_accion=p_dat_cons_cas.tip_edicion;
                    g_lugar := 'Actualizar ge_spi_cli_cas';

                 if sql%rowcount > 0 then
                  begin
                    update ge_spi_cli_cas
                    set est_cliente= p_dat_cons_cas.est_cliente
                    where tip_identificador = v_tip_identificador
                    and val_identificador   = v_val_identificador
                    and cli_recordid        = p_dat_cons_cas.cli_recordID;

                    if sql%rowcount > 0 then
                       /*recupero datos de persona*/
                         begin
                          select p.cod_persona
                          into v_cod_persona
                          from ba_personas p
                          where p.nro_documento=v_val_identificador;
                         exception
                           when no_data_found then
                             v_cod_persona:= null;
                         end;

                     v_inf_json:='{'||'"tip_documento":'   ||'"'||v_tip_identificador        ||'"'||','||
                                     '"nro_documento":'    ||'"'||v_val_identificador        ||'"'||','||
                                     '"nombre":'           ||'"'||v_nombre                   ||'"'||','||
                                     '"apellido":'         ||'"'||v_apellido                 ||'"'||','||
                                     '"est_cliente":'      ||'"'||p_dat_cons_cas.est_cliente ||'"'|| '}';
                       if  p_dat_cons_cas.tip_canal is null then
                               if fu_obt_tip_per(v_cod_persona) = 'F' then
                                    pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTACLCAS'),v_inf_json);
                                    p_dat_mensaje         := mensaje;
                                 elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                                   pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTACLCASPJ'),v_inf_json);
                                   p_dat_mensaje         := mensaje;
                                 else
                                   p_dat_mensaje         := mensaje;
                                 end if;
                       elsif p_dat_cons_cas.tip_canal = 'WEBA' then
                               /*se genera la notificacion de alta en un solo paso*/
                               if fu_obt_tip_per(v_cod_persona) = 'F' then
                                   p_dat_mensaje         := mensaje;
                               elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                                   p_dat_mensaje         := mensaje;
                               else
                                  p_dat_mensaje         := mensaje;
                               end if;
                       elsif p_dat_cons_cas.tip_canal = 'WEBE' then
                                /*se genera la notificacion de edicion en un solo paso*/
                               if fu_obt_tip_per(v_cod_persona) = 'F' then
                                    p_dat_mensaje         := mensaje;
                                elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                                   p_dat_mensaje         := mensaje;
                                else
                                   p_dat_mensaje         := mensaje;
                                end if;
                       end if;
                  else
                     mensaje.cod_respuesta := 4;
                     mensaje.nom_respuesta := 'Error';
                     mensaje.des_Respuesta := g_lugar;
                     p_dat_mensaje         := mensaje;
                  end if;
                  end;
                 else
                   mensaje.cod_respuesta := 3;
                     mensaje.nom_respuesta := 'Error';
                     mensaje.des_Respuesta := g_lugar;
                     p_dat_mensaje         := mensaje;
                 end if;
               end;
           else

                /*buscamos la descripcion del error*/
               v_descripcion_error:=fue_obt_des_refcodes('TIP_REC_CAS',p_dat_cons_cas.error) ;
               g_lugar := 'Actualizar ge_spi_cli_cas_temp';
               begin
                  update ge_spi_cli_cas_tmp c
                  set c.est_solicitud  = 'E',
                  c.error              = p_dat_cons_cas.error||' '||v_descripcion_error
                  where c.nro_referencia=p_dat_cons_cas.nro_referencia;

                   if sql%rowcount > 0 then
                      /*recupero datos de persona*/
                        begin
                          select p.cod_persona
                          into v_cod_persona
                          from ba_personas p
                          where p.nro_documento=v_val_identificador;
                         end;
                        v_inf_json:='{'||'"tip_documento":'   ||'"'||v_tip_identificador        ||'"'||','||
                                     '"nro_documento":'    ||'"'||v_val_identificador        ||'"'||','||
                                     '"nombre":'           ||'"'||v_nombre                   ||'"'||','||
                                     '"apellido":'         ||'"'||v_apellido                 ||'"'||','||
                                     '"est_cliente":'      ||'"'||p_dat_cons_cas.est_cliente ||'"'||','||
                                     '"error":'            ||'"'||v_descripcion_error        ||'"'|| '}';

                         if  p_dat_cons_cas.tip_canal is null then
                                 if fu_obt_tip_per(v_cod_persona) = 'F' then
                                      pas_spi.pr_env_alerta(v_cod_persona,
                                       fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTACNCAS'),v_inf_json);
                                      p_dat_mensaje         := mensaje;
                                   elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                                     pas_spi.pr_env_alerta(v_cod_persona,
                                     fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTACNCASPJ'),v_inf_json);
                                     p_dat_mensaje         := mensaje;
                                   else
                                     p_dat_mensaje         := mensaje;
                                   end if;
                         elsif p_dat_cons_cas.tip_canal = 'WEBA' then
                                 /*se genera la notificacion de alta en un solo paso*/
                                 if fu_obt_tip_per(v_cod_persona) = 'F' then
                                     p_dat_mensaje         := mensaje;
                                 elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                                     p_dat_mensaje         := mensaje;
                                 else
                                    p_dat_mensaje         := mensaje;
                                 end if;
                         elsif p_dat_cons_cas.tip_canal = 'WEBE' then
                                  /*se genera la notificacion de edicion en un solo paso*/
                                 if fu_obt_tip_per(v_cod_persona) = 'F' then
                                      p_dat_mensaje         := mensaje;
                                  elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                                     p_dat_mensaje         := mensaje;
                                  else
                                     p_dat_mensaje         := mensaje;
                                  end if;
                         end if;
                   else
                      mensaje.cod_respuesta := 5;
                      mensaje.nom_respuesta := 'Error';
                      mensaje.des_Respuesta := g_lugar;
                      p_dat_mensaje         := mensaje;
                   end if;
                 end;
            end if;
        ELSIF  p_dat_cons_cas.tip_edicion = 'ELI' THEN
           If p_dat_cons_cas.error is null then

                 g_lugar := 'Actualizar ge_spi_cli_cas_tmp';

                 begin
                    update ge_spi_cli_cas_tmp t
                     set est_solicitud='A'
                     where nro_referencia = p_dat_cons_cas.nro_referencia
                      and tip_accion=p_dat_cons_cas.tip_edicion;
                      g_lugar := 'Eliminar ge_spi_cli_cas';
                   if sql%rowcount > 0 then
                      begin

                         DELETE ge_spi_cli_cas
                            where tip_identificador = v_tip_identificador
                            and val_identificador   = v_val_identificador
                             and cli_recordid       = p_dat_cons_cas.cli_recordID;

                          if sql%rowcount > 0 then
                              begin
                            select p.cod_persona
                            into v_cod_persona
                            from ba_personas p
                            where p.nro_documento=v_val_identificador;
                            exception
                              when others then
                              v_cod_persona:= null ;
                           end;

                              v_inf_json:='{'||'"tip_documento":'  ||'"'||v_tip_identificador ||'"'||','||
                                               '"nro_documento":'  ||'"'||v_val_identificador ||'"'||','||
                                               '"nombre":'         ||'"'||v_nombre            ||'"'||','||
                                               '"apellido":'       ||'"'||v_apellido          ||'"'||','||
                                               '"est_cliente":'    ||'"'||p_dat_cons_cas.est_cliente||'"'|| '}';

                            if  p_dat_cons_cas.tip_canal is null then
                               if fu_obt_tip_per(v_cod_persona) = 'F' then
                                    pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTELCLCAS'),v_inf_json);
                                    p_dat_mensaje         := mensaje;
                                 elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                                   pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTELCLCASPJ'),v_inf_json);
                                   p_dat_mensaje         := mensaje;
                                 else
                                   p_dat_mensaje         := mensaje;
                                 end if;
                             elsif p_dat_cons_cas.tip_canal = 'WEBA' then
                               /*se genera la notificacion de alta en un solo paso*/
                               if fu_obt_tip_per(v_cod_persona) = 'F' then
                                   p_dat_mensaje         := mensaje;
                               elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                                   p_dat_mensaje         := mensaje;
                               else
                                  p_dat_mensaje         := mensaje;
                               end if;
                             elsif p_dat_cons_cas.tip_canal = 'WEBE' then
                                /*se genera la notificacion de edicion en un solo paso*/
                               if fu_obt_tip_per(v_cod_persona) = 'F' then
                                    p_dat_mensaje         := mensaje;
                                elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                                   p_dat_mensaje         := mensaje;
                                else
                                   p_dat_mensaje         := mensaje;
                                end if;
                             end if;
                          else
                           mensaje.cod_respuesta := 4;
                           mensaje.nom_respuesta := 'Error';
                           mensaje.des_Respuesta := g_lugar;
                           p_dat_mensaje         := mensaje;
                          end if;
                       end;
                   else
                     mensaje.cod_respuesta := 3;
                             mensaje.nom_respuesta := 'Error';
                             mensaje.des_Respuesta := g_lugar;
                             p_dat_mensaje         := mensaje;
                    end if;
                 end;

           else

                  /*buscamos la descripcion del error*/
               v_descripcion_error:=fue_obt_des_refcodes('TIP_REC_CAS',p_dat_cons_cas.error) ;
               g_lugar := 'Actualizar ge_spi_cli_cas_temp';
               begin
                 update ge_spi_cli_cas_tmp c
                    set c.est_solicitud   = 'E',
                         c.error          = p_dat_cons_cas.error||' '||v_descripcion_error
                 where c.nro_referencia = p_dat_cons_cas.nro_referencia;
                  if sql%rowcount > 0 then
                    begin
                          select p.cod_persona
                          into v_cod_persona
                          from ba_personas p
                          where p.nro_documento=v_val_identificador;
                     exception
                       when others then
                        v_cod_persona:= null;
                     end;
                        v_inf_json:='{'||'"tip_documento":'  ||'"'||v_tip_identificador ||'"'||','||
                                         '"nro_documento":'  ||'"'||v_val_identificador ||'"'||','||
                                         '"nombre":'         ||'"'||v_nombre            ||'"'||','||
                                         '"apellido":'       ||'"'||v_apellido          ||'"'||','||
                                         '"est_cliente":'    ||'"'||p_dat_cons_cas.est_cliente||'"'||','||
                                         '"Error":'          ||'"'||v_descripcion_error||'"'|| '}';
                             if  p_dat_cons_cas.tip_canal is null then
                               if fu_obt_tip_per(v_cod_persona) = 'F' then
                                    pas_spi.pr_env_alerta(v_cod_persona,
                                    fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTELCLNCAS'),v_inf_json);
                                    p_dat_mensaje         := mensaje;
                                 elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                                   pas_spi.pr_env_alerta(v_cod_persona,
                                    fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTELCLNCASPJ'),v_inf_json);
                                   p_dat_mensaje         := mensaje;
                                 else
                                   p_dat_mensaje         := mensaje;
                                 end if;
                             elsif p_dat_cons_cas.tip_canal = 'WEBA' then
                               /*se genera la notificacion de alta en un solo paso*/
                               if fu_obt_tip_per(v_cod_persona) = 'F' then
                                  p_dat_mensaje         := mensaje;
                               elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                                  p_dat_mensaje         := mensaje;
                               else
                                 p_dat_mensaje         := mensaje;
                               end if;
                             elsif p_dat_cons_cas.tip_canal = 'WEBE' then
                                /*se genera la notificacion de edicion en un solo paso*/
                               if fu_obt_tip_per(v_cod_persona) = 'F' then
                                    p_dat_mensaje         := mensaje;
                                elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                                   p_dat_mensaje         := mensaje;
                                else
                                   p_dat_mensaje         := mensaje;
                                end if;
                             end if;

                 else
                    mensaje.cod_respuesta := 3;
                      mensaje.nom_respuesta := 'Error';
                      mensaje.des_Respuesta := g_lugar;
                      p_dat_mensaje         := mensaje;
                  end if;
               end;
           end if;
        END IF;
  else
     g_lugar := 'Referencia recibida distinta enviada' ||
      '- Recibida: '|| p_dat_cons_cas.nro_referencia||
      '- Buscada: '||v_nro_referencia;

      mensaje.cod_respuesta := 2;
      mensaje.nom_respuesta := 'Error';
      mensaje.des_Respuesta := g_lugar;
      p_dat_mensaje         := mensaje;

    end if;
exception
  when others then
    mensaje.cod_respuesta := 1;
      mensaje.nom_respuesta := 'Error';
      mensaje.des_Respuesta := sqlerrm;
      p_dat_mensaje         := mensaje;
end pr_pro_msj_rec_edi_cas;

procedure pr_ins_cta_cas(p_dat_cta_cas in out typ_insctacas,
                         P_CANAL        in varchar2,
                         p_accion       in varchar2 default null ) is

  v_nro_referencia  ge_spi_cta_cas.nro_referencia%type;
  V_MONEDA          ba_monedas.cod_mon_iso%type;
  datosclie         typ_insctacas;
  v_cod_circuito    WF_TIP_CIRCUITOS.COD_TIP_CIRCUITO%type;
begin
  /*se controla que el modulo cas este activo para generar las consultas*/
  if FUG_OBT_PARDINAMICO('HAB_SPI_CAS') = 'S' then
     v_nro_referencia:=pas_cas.fu_obt_sig_ref_cas;
     V_MONEDA := fue_obt_mon_iso(pag_gen.fu_obt_mon_local, fue_obt_des_moneda(pag_gen.fu_obt_mon_local));

     begin
         insert into ge_spi_cta_cas c (nro_referencia,nro_cta_solicitante,cli_recordid,cta_recordid,
                  ali_recordid,cod_persona,tip_cuenta,fec_apertura,fec_cancelacion,moneda,
                  cta_por_defecto,est_solicitud,tip_identificador,identificador,tip_accion)

        values (v_nro_referencia,p_dat_cta_cas.nro_cta_solicitante,p_dat_cta_cas.cli_recordid, p_dat_cta_cas.cta_recordid,
               p_dat_cta_cas.ali_recordid, p_dat_cta_cas.cod_persona, p_dat_cta_cas.tip_cuenta, p_dat_cta_cas.fec_apertura,
               p_dat_cta_cas.fec_cancelacion, V_MONEDA, p_dat_cta_cas.cta_por_defecto,
               p_dat_cta_cas.est_solicitud, p_dat_cta_cas.tip_identificador, p_dat_cta_cas.identificador,p_accion );
         if sql%rowcount > 0 then
            if p_canal is null then
               v_cod_circuito:= fug_obt_pardinamico('PAS_CAS_CIR_ALTA_CTA');
                if paw_cir.fu_ini_circuito( v_cod_circuito,v_nro_referencia,  p_dat_cta_cas.cod_persona ) <> 0 then
                  pas_cas.g_cod_error := 50;
                  pas_cas.g_msj_error := 'No se ha podido iniciar el circuito ' || 155 ||'. '|| nvl( paw_cir.fu_obt_msj_error, sqlerrm );
                else
                  datosclie :=typ_insctacas(v_nro_referencia,null,null,null,null,null,null,null,
                  null,null,null,null,null,null);
                  p_dat_cta_cas := datosclie;
                end if;
            else
               datosclie := typ_insctacas();
               datosclie.nro_referencia:=v_nro_referencia;
               p_dat_cta_cas:= datosclie;
            end if;
        else
           pas_cas.g_msj_error := 'Error al registrar alta de cuenta de cliente '||sqlerrm;
            pas_cas.g_cod_error := 1;
        end if;
     end;

  elsif  FUG_OBT_PARDINAMICO('HAB_SPI_CAS') = 'N' then
   /*si el parametro esta en N no genera ni una solicitud de consulta*/
    pas_cas.g_msj_error := 'El módulo CAS no se encuentra habilitado.';
    pas_cas.g_cod_error := 30;
  end if;
exception
  when others then
     pas_cas.g_msj_error := 'Ocurrio un error. '||sqlerrm;
     pas_cas.g_cod_error := 1;
end pr_ins_cta_cas;

 procedure pr_obt_dat_cta_cas (p_dat_cab_cons_cas out typ_ObtdatCabconcas,
                               p_dat_cons_cas out typ_ObtRegctacas,
                               p_dat_mensaje out typ_mensajeria_spi) is

 v_nro_referencia  GE_SPI_cta_CAS.nro_referencia%type:=null;

 datoscue         typ_ObtRegctacas;

  mensaje         typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);

  cursor alta_cta is
  select nro_referencia ,
        nro_cta_solicitante,
        cli_recordID       ,
        cta_recordID       ,
        cod_persona        ,
        tip_cuenta         ,
        fec_apertura       ,
        fec_cancelacion    ,
        moneda             ,
        cta_por_defecto    ,
        est_solicitud      ,
        tip_accion
   from ge_spi_cta_cas
    where est_solicitud='U'
    AND ROWNUM=1
    order by  nro_referencia
    for update skip locked;

 begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    g_lugar:= 'Recorre solicitudes';
    for i in alta_cta loop
        v_nro_referencia:=i.nro_referencia;
        g_lugar:='Registro de parametros en log ';

        datoscue := typ_ObtRegctacas(i.nro_referencia, i.nro_cta_solicitante,
                                     i.cli_recordID, i.cta_recordID ,
                                      i.cod_persona,i.tip_cuenta ,
                                      i.fec_apertura, i.fec_cancelacion ,
                                      i.moneda, i.cta_por_defecto    ,
                                      i.est_solicitud,i.tip_accion);
           g_lugar:='Registro de parametros en log ';

           pas_cas.pr_reg_operacion('Nro_referencia: '    ||i.nro_referencia    || chr(10) ||
                                    'nro_cta_solicitante: ' ||i.nro_cta_solicitante || chr(10) ||
                                    'cli_recordID: '    ||i.cli_recordID        || chr(10) ||
                                    'cta_recordID: '    ||i.cta_recordID        || chr(10) ||
                                    'cod_persona : '    ||i.cod_persona         || chr(10) ||
                                    'tip_cuenta : '     ||i.tip_cuenta          || chr(10) ||
                                    'fec_apertura: '    ||i.fec_apertura        || chr(10) ||
                                    'fec_cancelacion: '   ||i.fec_cancelacion   || chr(10) ||
                                    'moneda:'             ||i.moneda            || chr(10) ||
                                    'cta_por_defecto: '   ||i.cta_por_defecto   || chr(10) ||
                                    'est_solicitud: '     ||i.est_solicitud     || chr(10) ||
                                    'tip_accion: '        ||i.tip_accion,       g_lugar    ||
                                    ' Nro_referencia: '   ||i.nro_referencia );














    end loop;
   if v_nro_referencia is not null then
    g_lugar:='Asigna datos para la cabecera';

    p_dat_cab_cons_cas :=PAS_CAS.fu_obt_dat_Cab_concas(v_nro_referencia);

    g_lugar:='Actualizacion de cliente a bloqueado';
      begin
         UPDATE GE_SPI_CTA_CAS
           SET Est_solicitud = 'B'
         WHERE nro_referencia = v_nro_referencia;
        if sql%rowcount > 0 then
          p_dat_cons_cas := datoscue;
          p_dat_mensaje   := mensaje;
       else
          mensaje.cod_respuesta := 2;
          mensaje.nom_respuesta := 'Error';
          mensaje.des_Respuesta := 'Error al bloquear Registro';
          p_dat_cons_cas        := datoscue;
          p_dat_mensaje         := mensaje;
       end if;
      end;
   else
    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Sin registros';
    mensaje.des_Respuesta := 'No existe registro a consultar';
    p_dat_cons_cas        := datoscue;
    p_dat_mensaje         := mensaje;
    end if;
exception
  when others then
    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Error';
    mensaje.des_Respuesta := 'Ocurrio un error. '||sqlerrm;
    p_dat_cons_cas        := datoscue;
    p_dat_mensaje         := mensaje;
 end pr_obt_dat_cta_cas;

 PROCEDURE pr_pro_msj_rec_cta_cas(p_res_cta_cas     in typ_ObtDatResCta,
                                  p_dat_mensaje      out typ_mensajeria_spi) is
v_nro_referencia       GE_SPI_CTA_CAS.NRO_REFERENCIA%type;
v_nro_cta_solicitante  GE_SPI_CTA_CAS.nro_cta_solicitante%type;
v_fec_apertura         GE_SPI_CTA_CAS.fec_apertura%type;
v_fec_cancelacion      GE_SPI_CTA_CAS.fec_cancelacion%type;
v_moneda               GE_SPI_CTA_CAS.moneda%type;
v_cta_por_defecto      GE_SPI_CTA_CAS.cta_por_defecto%type;
v_est_solicitud        GE_SPI_CTA_CAS.est_solicitud%type;
v_desc_mon           VARCHAR2(20);
v_cod_persona        GE_SPI_CTA_CAS.Cod_Persona%type;

mensaje                typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);
v_descripcion_error    varchar2(200);
v_inf_json                 long:=null;

begin
   begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;

  pas_cas.pr_ini_variables;
    g_lugar := 'Registro de parametros en log';
    pas_cas.pr_reg_operacion('Parametros=> Nro_referencia:' || p_res_cta_cas.nro_referencia|| chr(10) ||
                             'cta_recordID: '               || p_res_cta_cas.cta_recordID || chr(10)   ||
                             'Error: '                      || p_res_cta_cas.error        || chr(10)   ||
                             'tip_accion: '                 || p_res_cta_cas.tip_accion,
                             g_lugar|| ' Nro_referencia: ' || p_res_cta_cas.nro_referencia);
  g_lugar := 'Valida referencia';

       begin
        select c.nro_referencia,c.nro_cta_solicitante,c.fec_apertura,
               c.fec_cancelacion,c.moneda,c.cta_por_defecto, c.est_solicitud, c.cod_persona
        into v_nro_referencia,v_nro_cta_solicitante,v_fec_apertura,
        v_fec_cancelacion,v_moneda,v_cta_por_defecto,v_est_solicitud,v_cod_persona
        from ge_spi_cta_cas c
        where c.nro_referencia= p_res_cta_cas.nro_referencia;
       exception
         when no_data_found then
         v_nro_referencia := null;
         when others then
           g_lugar := 'Error al recuperar nro_referencia'||'-'|| p_res_cta_cas.nro_referencia;
           mensaje.cod_respuesta := 1;
           mensaje.nom_respuesta := 'Error';
           mensaje.des_Respuesta := g_lugar;
           p_dat_mensaje         := mensaje;
       end;
    if v_nro_referencia = p_res_cta_cas.nro_referencia then
       if p_res_cta_cas.error is null then
         g_lugar := 'Actualizar ge_spi_cta_cas';
          begin
            update ge_spi_cta_cas c
             set c.cta_recordid    = p_res_cta_cas.cta_recordID,
             c.est_solicitud       = 'A'
             where c.nro_referencia= p_res_cta_cas.nro_referencia;
            if sql%rowcount > 0 then
                 v_desc_mon:= FUE_OBT_DES_MONEDA(FUE_OBT_ISO_MONEDA(v_moneda));

               v_inf_json:='{'||'"nombre":'      ||'"'||FUE_OBT_NOM_PERSONA(v_cod_persona)               ||'"'||','||
                               '"nro_cta_solicitante":'         ||'"'||v_nro_cta_solicitante    ||'"'||','||
                               '"fec_apertura":'                 ||'"'||to_char(v_fec_apertura, 'DD/MM/YYYY')      ||'"'||','||
                               '"fec_cancelacion":'              ||'"'||to_char(v_fec_cancelacion, 'DD/MM/YYYY')   ||'"'||','||
                               '"moneda":'                       ||'"'||v_desc_mon          ||'"'||','||
                               '"cta_defecto":'                  ||'"'||v_cta_por_defecto   ||'"'||','||
                               '"est_solicitud":'                ||'"'||'Activo'  ||'"'||'}';

               if p_res_cta_cas.tip_accion is null  then
                 if fu_obt_tip_per(v_cod_persona) = 'F' then
                      pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTCUCAS'),v_inf_json);
                      p_dat_mensaje         := mensaje;
                  elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                     pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTCUCASPJ'),v_inf_json);
                     p_dat_mensaje         := mensaje;
                  else
                     p_dat_mensaje         := mensaje;
                  end if;
               elsif p_res_cta_cas.tip_accion='E' or  p_res_cta_cas.tip_accion = 'A'  then
                 /*alerta de alta en un solo paso o edicion desde la web
                  se generan al final el alta de alias */
                   p_dat_mensaje         := mensaje;
               else
                 null;
               end if;
            else
             mensaje.cod_respuesta := 3;
             mensaje.nom_respuesta := 'Error';
             mensaje.des_Respuesta := g_lugar;
             p_dat_mensaje         := mensaje;
            end if;
          end;

       else
          v_descripcion_error:=fue_obt_des_refcodes('TIP_REC_CAS',p_res_cta_cas.error) ;
           g_lugar := 'Actualizar ge_spi_cta_cas';
           begin

              update ge_spi_cta_cas c
               set c.est_solicitud       = 'E',
                   c.error                 = p_res_cta_cas.error||' '||v_descripcion_error
               where c.nro_referencia=p_res_cta_cas.nro_referencia;
              if sql%rowcount > 0 then
                 v_desc_mon:= FUE_OBT_DES_MONEDA(FUE_OBT_ISO_MONEDA(v_moneda));


                 v_inf_json:='{'||'"nombre":'            ||'"'||FUE_OBT_NOM_PERSONA(v_cod_persona)   ||'"'||','||
                               '"nro_cta_solicitante":'  ||'"'||v_nro_cta_solicitante    ||'"'||','||
                               '"fec_apertura":'         ||'"'||to_char(v_fec_apertura, 'DD/MM/YYYY')      ||'"'||','||
                               '"fec_cancelacion":'      ||'"'||to_char(v_fec_cancelacion, 'DD/MM/YYYY')   ||'"'||','||
                               '"moneda":'               ||'"'||v_desc_mon          ||'"'||','||
                               '"cta_defecto":'          ||'"'||v_cta_por_defecto   ||'"'||','||
                               '"est_solicitud":'        ||'"'||'Error'             ||'"'||','||
                               '"error":'                ||'"'||v_descripcion_error||'"'||'}';
                     if p_res_cta_cas.tip_accion is null  then
                        if fu_obt_tip_per(v_cod_persona) = 'F' then
                          pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTCNCAS'),v_inf_json);
                          p_dat_mensaje         := mensaje;
                      elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                         pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTCNCASPJ'),v_inf_json);
                         p_dat_mensaje         := mensaje;
                      else
                         p_dat_mensaje         := mensaje;
                      end if;
                     elsif p_res_cta_cas.tip_accion='E' or  p_res_cta_cas.tip_accion = 'A'  then
                       /*alerta de alta en un solo paso o edicion desde la web
                        se generan al final el alta de alias */
                        p_dat_mensaje         := mensaje;
                     end if;
             else
             mensaje.cod_respuesta := 3;
              mensaje.nom_respuesta := 'Error';
              mensaje.des_Respuesta := g_lugar;
              p_dat_mensaje         := mensaje;
             end if;
           end;
       end if;
     else
        g_lugar := 'Referencia recibida distinta enviada' ||
      '- Recibida: '|| p_res_cta_cas.nro_referencia||
      '- Buscada: '||v_nro_referencia;

      mensaje.cod_respuesta := 2;
      mensaje.nom_respuesta := 'Error';
      mensaje.des_Respuesta := g_lugar;
      p_dat_mensaje         := mensaje;
    end if;
exception
  when others then
   mensaje.cod_respuesta := 1;
      mensaje.nom_respuesta := 'Ocurrio un error';
      mensaje.des_Respuesta := g_lugar||' '||sqlerrm;
      p_dat_mensaje         := mensaje;
end pr_pro_msj_rec_cta_cas;

 procedure pr_edi_cta_cas(p_dat_cta_cas in out typ_insctacas,
                          p_accion       in varchar2,
                          p_canal       in varchar2 default null ) is

v_nro_referencia  GE_SPI_CON_CAS.nro_referencia%type;
  v_cod_persona     ba_personas.cod_persona%type;
  v_tip_acccion       varchar(20);
  v_est_solicitud     varchar2(1);
  v_canal             varchar2(3) default null;
  datosclie         typ_insctacas;
  v_cod_circuito    WF_TIP_CIRCUITOS.COD_TIP_CIRCUITO%type;
begin
  /*se controla que el modulo cas este activo para generar las consultas*/
  if FUG_OBT_PARDINAMICO('HAB_SPI_CAS') = 'S' then
     v_nro_referencia:= pas_cas.fu_obt_sig_ref_cas;

    if p_accion ='EDI' THEN
       v_tip_acccion:='Edición';
     elsif p_accion ='CON' THEN
        v_tip_acccion:='Conf. Cta. defecto';
     elsif p_accion ='ELI'THEN
        v_tip_acccion:='Eliminación';
     END IF;

    if p_canal is null then
      /*viende desde itgf*/
      v_est_solicitud := 'P';
    else
      /*viende desde web*/
      v_est_solicitud := 'U';
      --v_canal := 'WEB';
    end if;

    begin
     insert into ge_spi_cta_cas_tmp (nro_referencia, nro_cta_solicitante, cli_recordid, cta_recordid, ali_recordid,
     cod_persona, tip_cuenta, fec_apertura, fec_cancelacion, moneda, cta_por_defecto, error, est_solicitud,
     tip_identificador, identificador, tip_accion,tip_canal)

    values (v_nro_referencia,p_dat_cta_cas.nro_cta_solicitante,p_dat_cta_cas.cli_recordid, p_dat_cta_cas.cta_recordid,
    p_dat_cta_cas.ali_recordid,p_dat_cta_cas.cod_persona, p_dat_cta_cas.tip_cuenta, p_dat_cta_cas.fec_apertura,
    p_dat_cta_cas.fec_cancelacion, p_dat_cta_cas.moneda, p_dat_cta_cas.cta_por_defecto, NULL,
    v_est_solicitud,p_dat_cta_cas.tip_identificador, p_dat_cta_cas.identificador, p_accion,p_canal);

      if sql%rowcount > 0 then
        if p_canal is null then
           if p_accion = 'EDI' THEN
             v_cod_circuito:= fug_obt_pardinamico('PAS_CAS_CIR_EDI_CTA');
                  if paw_cir.fu_ini_circuito( v_cod_circuito,v_nro_referencia, p_dat_cta_cas.cod_persona ) <> 0 then
                    pas_cas.g_cod_error := 50;
                    pas_cas.g_msj_error := 'No se ha podido iniciar el circuito ' || 157 ||'. '|| nvl( paw_cir.fu_obt_msj_error, sqlerrm );
                  else
                   datosclie :=typ_insctacas(v_nro_referencia,null,null,null,null,null,null,null,
                              null,null,null,null,null,null);
                   p_dat_cta_cas := datosclie;
                  end if;
           ELSIF p_accion ='ELI' THEN
             v_cod_circuito:= fug_obt_pardinamico('PAS_CAS_CIR_ELI_CTA');
                  if paw_cir.fu_ini_circuito( v_cod_circuito,v_nro_referencia, p_dat_cta_cas.cod_persona ) <> 0 then
                    pas_cas.g_cod_error := 50;
                    pas_cas.g_msj_error := 'No se ha podido iniciar el circuito ' || 158 ||'. '|| nvl( paw_cir.fu_obt_msj_error, sqlerrm );
                  else
                   datosclie :=typ_insctacas(v_nro_referencia,null,null,null,null,null,null,null,
                              null,null,null,null,null,null);
                   p_dat_cta_cas := datosclie;
                  end if;
           ELSIF p_accion ='CON' THEN
             v_cod_circuito:= fug_obt_pardinamico('PAS_CAS_CIR_CON_CTA');
                   if paw_cir.fu_ini_circuito( v_cod_circuito,v_nro_referencia, p_dat_cta_cas.cod_persona ) <> 0 then
                      pas_cas.g_cod_error := 50;
                      pas_cas.g_msj_error := 'No se ha podido iniciar el circuito ' || 159 ||'. '|| nvl( paw_cir.fu_obt_msj_error, sqlerrm );
                   else
                   datosclie :=typ_insctacas(v_nro_referencia,null,null,null,null,null,null,null,
                              null,null,null,null,null,null);
                   p_dat_cta_cas := datosclie;
                  end if;
           END IF;
        end if;
      else
        pas_cas.g_msj_error := 'Error al registrar la '||v_tip_acccion||'del cliente '||sqlerrm;
        pas_cas.g_cod_error := 1;
      end if;
    end;

  elsif  FUG_OBT_PARDINAMICO('HAB_SPI_CAS') = 'N' then
   /*si el parametro esta en N no genera ni una solicitud de consulta*/
    pas_cas.g_msj_error := 'El módulo CAS no se encuentra habilitado.';
    pas_cas.g_cod_error := 30;
  end if;
exception
  when others then
    pas_cas.g_msj_error := 'Ocurrio un error. '||sqlerrm;
    pas_cas.g_cod_error := 1;
end pr_edi_cta_cas ;

procedure pr_obt_dat_conf_cta_cas( p_dat_cab_cons_cas     out typ_ObtdatCabconcas,
                                   p_dat_cons_cas         out typ_ObtRegedictacas,
                                   p_dat_mensaje          out typ_mensajeria_spi) is

 v_nro_referencia  GE_SPI_cta_CAS.nro_referencia%type:=null;
 datoscue         typ_ObtRegedictacas;
 mensaje          typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);

 cursor edi_cta is
 select nro_referencia,
        nro_cta_solicitante ,
        cli_recordID ,
        cta_recordID ,
        ali_recordid ,
        cod_persona  ,
        fec_cancelacion ,
        moneda ,
        cta_por_defecto ,
        est_solicitud,
        tip_identificador,
        identificador,
        tip_accion,
        tip_canal
  from ge_spi_cta_cas_tmp t
  where t.est_solicitud = 'U'
  AND ROWNUM=1
  order by  nro_referencia
  for update skip locked;
begin
   begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    g_lugar:= 'Recorre solicitudes';
    for i in  edi_cta loop
        v_nro_referencia:=i.nro_referencia;

        g_lugar:='Registro de parametros en log ';

        datoscue := typ_ObtRegedictacas (i.nro_referencia, i.nro_cta_solicitante, i.cli_recordID,
        i.cta_recordID,i.ali_recordid,i.cod_persona,i.fec_cancelacion,i.moneda,
        i.cta_por_defecto, i.est_solicitud,i.tip_identificador,i.identificador,
        i.tip_accion,null,i.tip_canal);

        g_lugar:='Registro de parametros en log ';
         pas_cas.pr_reg_operacion('nro_referencia: '        ||  i.nro_referencia       || chr(10) ||
                                  'nro_cta_solicitante : '  ||  i.nro_cta_solicitante  || chr(10) ||
                                  'cli_recordID : '         ||  i.cli_recordID         || chr(10) ||
                                  'cta_recordID : '         ||  i.cta_recordID         || chr(10) ||
                                  'ali_recordid  : '        ||  i.ali_recordid         || chr(10) ||
                                  'cod_persona  : '         ||  i.cod_persona          || chr(10) ||
                                  'fec_cancelacion : '      ||  i.fec_cancelacion      || chr(10) ||
                                  'moneda : '               ||  i.moneda               || chr(10) ||
                                  'cta_por_defecto : '      ||  i.cta_por_defecto      || chr(10) ||
                                  'est_solicitud: '         ||  i.est_solicitud        || chr(10) ||
                                  'tip_identificador: '     ||  i.tip_identificador    || chr(10) ||
                                  'identificador: '         ||  i.identificador        || chr(10) ||
                                  'tip_accion: '            ||  i.tip_accion           || chr(10) ||
                                  'Tip_canal: '             ||  i.tip_canal,           g_lugar ||
                                  ' Nro_referencia: '   ||i.nro_referencia );
    end loop;

   if v_nro_referencia is not null then
     g_lugar:='Asigna datos para la cabecera';

      p_dat_cab_cons_cas :=PAS_CAS.fu_obt_dat_Cab_concas(v_nro_referencia);

      g_lugar:='Actualizacion de cliente a bloqueado';
      begin
        UPDATE GE_SPI_CTA_CAS_tmp
         SET Est_solicitud = 'B'
        WHERE nro_referencia = v_nro_referencia;
        if sql%rowcount > 0 then
          p_dat_cons_cas := datoscue;
          p_dat_mensaje   := mensaje;
      else
         mensaje.cod_respuesta := 1;
        mensaje.nom_respuesta := 'Error';
        mensaje.des_Respuesta := 'Error al bloquear registro';
        p_dat_cons_cas        := datoscue;
        p_dat_mensaje         := mensaje;
      end if;
      end;

   else
    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Sin registros';
    mensaje.des_Respuesta := 'No existe registro a consultar';
    p_dat_cons_cas        := datoscue;
    p_dat_mensaje         := mensaje;
    end if;
exception
  when others then
     mensaje.cod_respuesta := 1;
     mensaje.nom_respuesta := 'Error';
     mensaje.des_Respuesta := 'Ocurrio un error';
     p_dat_cons_cas        := datoscue;
     p_dat_mensaje         := mensaje;
end pr_obt_dat_conf_cta_cas;

procedure pr_pro_msj_rec_edi_cta (p_dat_cons_cas  in typ_ObtRegedictacas,
                                   p_dat_mensaje  out typ_mensajeria_spi) is

v_nro_referencia       GE_SPI_CTA_CAS.NRO_REFERENCIA%type;
mensaje                typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);

v_cod_persona          GE_SPI_CTA_CAS.COD_PERSONA%type;
v_fec_cancel           GE_SPI_CTA_CAS.FEC_CANCELACION%type;
v_tip_identificador    GE_SPI_CTA_CAS.TIP_IDENTIFICADOR%type;
v_identificador        GE_SPI_CTA_CAS.IDENTIFICADOR%type;
v_cod_moneda           GE_SPI_CTA_CAS.MONEDA%type;
v_fec_apertura         ge_spi_cta_cas.fec_apertura%type;
v_desc_mon             varchar2(20);
v_cta_defecto          varchar2(2);
v_descripcion_error    varchar2(200);
v_nro_cta_solicitante   GE_SPI_CTA_CAS.NRO_CTA_SOLICITANTE%type;
v_inf_json                 long:=null;
begin
  begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;

  pas_cas.pr_ini_variables;
    g_lugar := 'Registro de parametros en log';
     pas_cas.pr_reg_operacion('Parametros=> nro_referencia: '  ||  p_dat_cons_cas.nro_referencia       || chr(10) ||
                              'nro_cta_solicitante : '         ||  p_dat_cons_cas.nro_cta_solicitante  || chr(10) ||
                              'cli_recordID : '                ||  p_dat_cons_cas.cli_recordID         || chr(10) ||
                              'cta_recordID : '                ||  p_dat_cons_cas.cta_recordID         || chr(10) ||
                              'ali_recordid  : '               ||  p_dat_cons_cas.ali_recordid         || chr(10) ||
                              'cod_persona  : '                ||  p_dat_cons_cas.cod_persona          || chr(10) ||
                              'fec_cancelacion : '             ||  p_dat_cons_cas.fec_cancelacion      || chr(10) ||
                              'moneda : '                      ||  p_dat_cons_cas.moneda               || chr(10) ||
                              'cta_por_defecto : '             ||  p_dat_cons_cas.cta_por_defecto      || chr(10) ||
                              'est_solicitud: '                ||  p_dat_cons_cas.est_solicitud        || chr(10) ||
                              'tip_identificador: '            ||  p_dat_cons_cas.tip_identificador    || chr(10) ||
                              'identificador: '                ||  p_dat_cons_cas.identificador        || chr(10) ||
                              'tip_accion: '                   ||  p_dat_cons_cas.tip_edicion          || chr(10) ||
                              'Error: '                        ||  p_dat_cons_cas.error                || chr(10) ||
                              'Tip_canal: '                    ||  p_dat_cons_cas.tip_canal,
                              g_lugar|| ' Nro_referencia: ' || p_dat_cons_cas.nro_referencia);
   g_lugar := 'Valida referencia';
       begin
        select c.nro_referencia,c.tip_identificador,c.identificador,
               cod_persona, fec_cancelacion,c.moneda,fec_apertura,c.nro_cta_solicitante
        into v_nro_referencia,v_tip_identificador,v_identificador,
        v_cod_persona,v_fec_cancel,v_cod_moneda,v_fec_apertura,v_nro_cta_solicitante
        from ge_spi_cta_cas_tmp c
        where c.nro_referencia= p_dat_cons_cas.nro_referencia;
       exception
         when no_data_found then
         v_nro_referencia := null;

         when others then
           g_lugar := 'Error al recuperar nro_referencia'||'-'|| p_dat_cons_cas.nro_referencia;
           mensaje.cod_respuesta := 1;
           mensaje.nom_respuesta := 'Error';
           mensaje.des_Respuesta := g_lugar;
           p_dat_mensaje         := mensaje;
      end;

    if v_nro_referencia = p_dat_cons_cas.nro_referencia then
       if p_dat_cons_cas.tip_edicion ='EDI' THEN
         if p_dat_cons_cas.error is null then
            g_lugar := 'Actualizar ge_spi_cta_cas_tmp';
            begin
               update  ge_spi_cta_cas_tmp  t
                set t.est_solicitud = 'A'
                where t.nro_referencia= p_dat_cons_cas.nro_referencia;
                  g_lugar := 'Actualizar ge_spi_cta_cas';
                if sql%rowcount > 0 then
                 begin
                      update ge_spi_cta_cas t
                      set t.fec_cancelacion   = p_dat_cons_cas.fec_cancelacion
                      where t.cod_persona     = v_cod_persona
                      and t.tip_identificador = v_tip_identificador
                      and t.identificador     = v_identificador
                      and t.cta_recordid      = p_dat_cons_cas.cta_recordID;
                     if sql%rowcount > 0 then
                        v_desc_mon:= FUE_OBT_DES_MONEDA(FUE_OBT_ISO_MONEDA(v_cod_moneda));

                         v_inf_json:='{'||'"nombre":'      ||'"'||FUE_OBT_NOM_PERSONA(v_cod_persona)   ||'"'||','||
                                         '"nro_cta_solicitante":'   ||'"'||v_nro_cta_solicitante         ||'"'||','||
                                         '"fec_cancelacion":'        ||'"'||to_char(p_dat_cons_cas.fec_cancelacion, 'DD/MM/YYYY')||'"'||','||
                                         '"moneda":'                 ||'"'||v_desc_mon                    ||'"'||','||
                                         '"est_solicitud":'          ||'"'||'Aprobado'                    ||'"'||'}';

                      if  p_dat_cons_cas.tip_canal is null then
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                             pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTEDCU'),v_inf_json);
                              p_dat_mensaje         := mensaje;
                           elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                             pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTEDCUPJ'),v_inf_json);
                             p_dat_mensaje         := mensaje;
                           else
                             p_dat_mensaje         := mensaje;
                           end if;
                       elsif p_dat_cons_cas.tip_canal = 'WEBA' then
                         /*se genera la notificacion de alta en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                             p_dat_mensaje         := mensaje;
                         elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                             p_dat_mensaje         := mensaje;
                         else
                            p_dat_mensaje         := mensaje;
                         end if;
                       elsif p_dat_cons_cas.tip_canal = 'WEBE' then
                          /*se genera la notificacion de edicion en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                              p_dat_mensaje         := mensaje;

                          elsif fu_obt_tip_per(v_cod_persona) = 'J' then

                             p_dat_mensaje         := mensaje;
                          else
                             p_dat_mensaje         := mensaje;
                          end if;
                       end if;
                     else
                        mensaje.cod_respuesta := 4;
                         mensaje.nom_respuesta := 'Error';
                         mensaje.des_Respuesta := g_lugar;
                         p_dat_mensaje         := mensaje;
                      end if;
                  end;
                else
                  mensaje.cod_respuesta := 3;
                     mensaje.nom_respuesta := 'Error';
                     mensaje.des_Respuesta := g_lugar;
                     p_dat_mensaje         := mensaje;
                end if;
            end;
         ELSE
             /*buscamos la descripcion del error*/
              v_descripcion_error:=fue_obt_des_refcodes('TIP_REC_CAS',p_dat_cons_cas.error) ;
               g_lugar := 'Actualizar error en  ge_spi_cta_cas_tmp';
               begin
                 update ge_spi_cta_cas_tmp c
                 set c.est_solicitud   = 'E',
                     c.error           = p_dat_cons_cas.error||' '||v_descripcion_error
                where c.nro_referencia = p_dat_cons_cas.nro_referencia;
                 if sql%rowcount > 0 then
                   v_desc_mon:= FUE_OBT_DES_MONEDA(FUE_OBT_ISO_MONEDA(v_cod_moneda));

                   v_inf_json:='{'||'"nombre":'      ||'"'||FUE_OBT_NOM_PERSONA(v_cod_persona)  ||'"'||','||
                                 '"nro_cta_solicitante":'  ||'"'||v_nro_cta_solicitante    ||'"'||','||
                                 '"fec_cancelacion":'      ||'"'||to_char(v_fec_cancel, 'DD/MM/YYYY')||'"'||','||
                                 '"moneda":'               ||'"'||v_desc_mon               ||'"'||','||
                                 '"est_solicitud":'        ||'"'||'Error'                  ||'"'||','||
                                 '"error":'                ||'"'||v_descripcion_error      ||'"'||'}';
                   if  p_dat_cons_cas.tip_canal is null then
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                             pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTEDNCUPJ'),v_inf_json);
                             p_dat_mensaje         := mensaje;
                           elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                             p_dat_mensaje         := mensaje;
                           else
                             p_dat_mensaje         := mensaje;
                           end if;
                   elsif p_dat_cons_cas.tip_canal = 'WEBA' then
                         /*no se genera la notificacion de alta en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                             p_dat_mensaje         := mensaje;
                         elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                              p_dat_mensaje         := mensaje;
                         else
                             p_dat_mensaje         := mensaje;
                         end if;
                   elsif p_dat_cons_cas.tip_canal = 'WEBE' then
                          /* no se genera la notificacion de edicion en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                              p_dat_mensaje         := mensaje;
                          elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                             p_dat_mensaje         := mensaje;
                          else
                             p_dat_mensaje         := mensaje;
                          end if;
                   end if;
               else
                   mensaje.cod_respuesta := 3;
                  mensaje.nom_respuesta := 'Error';
                  mensaje.des_Respuesta := g_lugar;
                  p_dat_mensaje         := mensaje;
               end if;
               end;
         END IF;
       ELSIF p_dat_cons_cas.tip_edicion ='CON' then
            if p_dat_cons_cas.error is null then
                 g_lugar := 'Actualizar ge_spi_cta_cas_tmp';
               begin
                  update  ge_spi_cta_cas_tmp  t
                  set t.est_solicitud='A'
                  where t.nro_referencia= p_dat_cons_cas.nro_referencia;
                   g_lugar := 'Actualizar ge_spi_cta_cas';
                if sql%rowcount > 0 then
                    begin
                       update  ge_spi_cta_cas  t
                        set t.cta_por_defecto   = p_dat_cons_cas.cta_por_defecto
                        where t.cod_persona     = v_cod_persona
                        and t.tip_identificador = v_tip_identificador
                        and t.identificador     = v_identificador
                        and t.cta_recordid      = p_dat_cons_cas.cta_recordID;
                    if sql%rowcount > 0 then
                       v_desc_mon:= FUE_OBT_DES_MONEDA(FUE_OBT_ISO_MONEDA(v_cod_moneda));
                      if p_dat_cons_cas.cta_por_defecto ='S' then
                         v_cta_defecto := 'Si';
                      else
                         v_cta_defecto := 'No';
                      end if;


                          v_inf_json:='{'||'"nombre":'      ||'"'||FUE_OBT_NOM_PERSONA(v_cod_persona)  ||'"'||','||
                                   '"nro_cta_solicitante":' ||'"'||v_nro_cta_solicitante         ||'"'||','||
                                   '"fec_apertura":'        ||'"'||to_char(v_fec_apertura, 'DD/MM/YYYY')                ||'"'||','||
                                   '"fec_cancelacion":'     ||'"'||to_char(p_dat_cons_cas.fec_cancelacion, 'DD/MM/YYYY')||'"'||','||
                                   '"moneda":'              ||'"'||v_desc_mon                    ||'"'||','||
                                   '"cta_defecto":'         ||'"'||p_dat_cons_cas.cta_por_defecto||'"'||','||
                                   '"est_solicitud":'       ||'"'||'Aprobado'                      ||'"'||'}';

                      if  p_dat_cons_cas.tip_canal is null then
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                             pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTCOCU'),v_inf_json);
                             p_dat_mensaje         := mensaje;
                           elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                             pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTCOCUPJ'),v_inf_json);
                             p_dat_mensaje         := mensaje;
                           else
                             p_dat_mensaje         := mensaje;
                           end if;
                      elsif p_dat_cons_cas.tip_canal = 'WEBA' then
                         /*se genera la notificacion de alta en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                             p_dat_mensaje         := mensaje;
                         elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                              p_dat_mensaje         := mensaje;
                         else
                             p_dat_mensaje         := mensaje;
                         end if;
                      elsif p_dat_cons_cas.tip_canal = 'WEBE' then
                          /*se genera la notificacion de edicion en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                              p_dat_mensaje         := mensaje;
                          elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                             p_dat_mensaje         := mensaje;
                          else
                             p_dat_mensaje         := mensaje;
                          end if;
                      end if;
                    else
                      mensaje.cod_respuesta := 4;
                      mensaje.nom_respuesta := 'Error';
                      mensaje.des_Respuesta := g_lugar;
                      p_dat_mensaje         := mensaje;
                   end if;
                   end;
               else
                    mensaje.cod_respuesta := 3;
                     mensaje.nom_respuesta := 'Error';
                     mensaje.des_Respuesta := g_lugar;
                     p_dat_mensaje         := mensaje;
               end if;
               end;
           ELSE
                /*buscamos la descripcion del error*/
                 v_descripcion_error:=fue_obt_des_refcodes('TIP_REC_CAS',p_dat_cons_cas.error) ;
              g_lugar := 'Actualizar error en  ge_spi_cta_cas_tmp';
              begin
                   update ge_spi_cta_cas_tmp c
                   set c.est_solicitud  = 'E',
                       c.error          = p_dat_cons_cas.error||' '||v_descripcion_error
                   where c.nro_referencia = p_dat_cons_cas.nro_referencia;
                 if sql%rowcount > 0 then
                    v_desc_mon:= FUE_OBT_DES_MONEDA(FUE_OBT_ISO_MONEDA(v_cod_moneda));

                      if p_dat_cons_cas.cta_por_defecto ='S' then
                         v_cta_defecto := 'Si';
                      else
                         v_cta_defecto := 'No';
                      end if;


                   v_inf_json:='{'||'"nombre":'          ||'"'||FUE_OBT_NOM_PERSONA(v_cod_persona)  ||'"'||','||
                                   '"nro_cta_solicitante":'   ||'"'||v_nro_cta_solicitante         ||'"'||','||
                                   '"fec_apertura":'           ||'"'||to_char(v_fec_apertura, 'DD/MM/YYYY')                ||'"'||','||
                                   '"fec_cancelacion":'        ||'"'||to_char(p_dat_cons_cas.fec_cancelacion, 'DD/MM/YYYY')||'"'||','||
                                   '"moneda":'                 ||'"'||v_desc_mon                    ||'"'||','||
                                   '"cta_defecto":'            ||'"'||p_dat_cons_cas.cta_por_defecto||'"'||','||
                                   '"est_solicitud":'          ||'"'||'Error'                       ||'"'||','||
                                   '"error":'                  ||'"'||v_descripcion_error           ||'"'||'}';
                    if  p_dat_cons_cas.tip_canal is null then
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                             pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTCNCU'),v_inf_json);
                             p_dat_mensaje         := mensaje;
                           elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                             pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTCNCUPJ'),v_inf_json);
                             p_dat_mensaje         := mensaje;
                           else
                             p_dat_mensaje         := mensaje;
                           end if;
                    elsif p_dat_cons_cas.tip_canal = 'WEBA' then
                         /*se genera la notificacion de alta en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                            p_dat_mensaje         := mensaje;
                         elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                             p_dat_mensaje         := mensaje;
                         else
                           p_dat_mensaje         := mensaje;
                         end if;
                    elsif p_dat_cons_cas.tip_canal = 'WEBE' then
                          /*se genera la notificacion de edicion en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                              p_dat_mensaje         := mensaje;
                          elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                             p_dat_mensaje         := mensaje;
                          else
                             p_dat_mensaje         := mensaje;
                          end if;
                    end if;
                Else
                  mensaje.cod_respuesta := 3;
                      mensaje.nom_respuesta := 'Error';
                      mensaje.des_Respuesta := g_lugar;
                      p_dat_mensaje         := mensaje;
               end if;
               end;
           END IF;
       ELSIF p_dat_cons_cas.tip_edicion ='ELI' then
            if p_dat_cons_cas.error is null then
                g_lugar := 'Actualizar ge_spi_cta_cas_tmp';
               begin
                /*caso especial para eliminacion de cuenta
                cuando se elimina se paso al estado "D" en la solicitud*/
                  update  ge_spi_cta_cas_tmp  t
                  set t.est_solicitud='D'
                  where t.nro_referencia= p_dat_cons_cas.nro_referencia;
                  g_lugar := 'Elimina ge_spi_cta_cas';
                if sql%rowcount > 0 then
                   begin
                      delete ge_spi_cta_cas c
                       where c.tip_identificador = v_tip_identificador
                       and c.identificador       = v_identificador
                       and c.cod_persona         = v_cod_persona
                       and c.cta_recordid        = p_dat_cons_cas.cta_recordID;
                     if sql%rowcount > 0 then
                       v_desc_mon:= FUE_OBT_DES_MONEDA(FUE_OBT_ISO_MONEDA(v_cod_moneda));

                       if p_dat_cons_cas.cta_por_defecto ='S' then
                         v_cta_defecto := 'Si';
                      else
                         v_cta_defecto := 'No';
                      end if;


                       v_inf_json:='{'||'"nombre":'      ||'"'||FUE_OBT_NOM_PERSONA(v_cod_persona)      ||'"'||','||
                                   '"nro_cta_solicitante":'        ||'"'||v_nro_cta_solicitante         ||'"'||','||
                                   '"fec_apertura":'                    ||'"'||to_char(v_fec_apertura, 'DD/MM/YYYY')                ||'"'||','||
                                   '"fec_cancelacion":'                 ||'"'||to_char(p_dat_cons_cas.fec_cancelacion, 'DD/MM/YYYY')||'"'||','||
                                   '"moneda":'                          ||'"'||v_desc_mon                    ||'"'||','||
                                   '"cta_defecto":'                     ||'"'||p_dat_cons_cas.cta_por_defecto||'"'||','||
                                   '"est_solicitud":'                   ||'"'||'Aprobado'                      ||'"'||'}';
                    if  p_dat_cons_cas.tip_canal is null then
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                             pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTELCU'),v_inf_json);
                             p_dat_mensaje         := mensaje;
                           elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                             pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTELCUPJ'),v_inf_json);
                             p_dat_mensaje         := mensaje;
                           else
                             p_dat_mensaje         := mensaje;
                           end if;
                    elsif p_dat_cons_cas.tip_canal = 'WEBA' then
                         /*se genera la notificacion de alta en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                             p_dat_mensaje         := mensaje;
                         elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                              p_dat_mensaje         := mensaje;
                         else
                             p_dat_mensaje         := mensaje;
                         end if;
                    elsif p_dat_cons_cas.tip_canal = 'WEBE' then
                          /*se genera la notificacion de edicion en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                              p_dat_mensaje         := mensaje;

                          elsif fu_obt_tip_per(v_cod_persona) = 'J' then

                             p_dat_mensaje         := mensaje;
                          else
                             p_dat_mensaje         := mensaje;
                          end if;
                    end if;
                   else
                     mensaje.cod_respuesta := 4;
                     mensaje.nom_respuesta := 'Error';
                     mensaje.des_Respuesta := g_lugar;
                     p_dat_mensaje         := mensaje;
                   end if;
                 end;
               else
                   mensaje.cod_respuesta := 3;
                     mensaje.nom_respuesta := 'Error';
                     mensaje.des_Respuesta := g_lugar;
                     p_dat_mensaje         := mensaje;
               end if;
               end;
           ELSE
              /*buscamos la descripcion del error*/
              v_descripcion_error:=fue_obt_des_refcodes('TIP_REC_CAS',p_dat_cons_cas.error) ;
               g_lugar := 'Actualizar error en  ge_spi_cta_cas_tmp';
               begin
                update ge_spi_cta_cas_tmp c
                 set c.est_solicitud  = 'E',
                     c.error          = p_dat_cons_cas.error||' '||v_descripcion_error
                 where c.nro_referencia = p_dat_cons_cas.nro_referencia;
                 if sql%rowcount > 0 then
                   v_desc_mon:= FUE_OBT_DES_MONEDA(FUE_OBT_ISO_MONEDA(v_cod_moneda));

                    if p_dat_cons_cas.cta_por_defecto ='S' then
                         v_cta_defecto := 'Si';
                      else
                         v_cta_defecto := 'No';
                      end if;


                    v_inf_json:='{'||'"nombre":'      ||'"'||FUE_OBT_NOM_PERSONA(v_cod_persona)     ||'"'||','||
                                   '"nro_cta_solicitante":'  ||'"'||v_nro_cta_solicitante           ||'"'||','||
                                   '"fec_apertura":'           ||'"'||to_char(v_fec_apertura, 'DD/MM/YYYY')                ||'"'||','||
                                   '"fec_cancelacion":'        ||'"'||to_char(p_dat_cons_cas.fec_cancelacion, 'DD/MM/YYYY')||'"'||','||
                                   '"moneda":'                 ||'"'||v_desc_mon                    ||'"'||','||
                                   '"cta_defecto":'            ||'"'||p_dat_cons_cas.cta_por_defecto||'"'||','||
                                   '"est_solicitud":'          ||'"'||'Error'                       ||'"'||','||
                                   '"error":'                  ||'"'||v_descripcion_error           ||'"'||'}';
                     if  p_dat_cons_cas.tip_canal is null then
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                              pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTENCU'),v_inf_json);
                              p_dat_mensaje         := mensaje;
                           elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                             pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTENCUPJ'),v_inf_json);
                             p_dat_mensaje         := mensaje;
                           else
                             p_dat_mensaje         := mensaje;
                           end if;
                    elsif p_dat_cons_cas.tip_canal = 'WEBA' then
                         /*se genera la notificacion de alta en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                              p_dat_mensaje         := mensaje;
                         elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                              p_dat_mensaje         := mensaje;
                         else
                             p_dat_mensaje         := mensaje;
                         end if;
                    elsif p_dat_cons_cas.tip_canal = 'WEBE' then
                          /*se genera la notificacion de edicion en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                              p_dat_mensaje         := mensaje;

                          elsif fu_obt_tip_per(v_cod_persona) = 'J' then

                             p_dat_mensaje         := mensaje;
                          else
                             p_dat_mensaje         := mensaje;
                          end if;
                    end if;

               else
                mensaje.cod_respuesta := 3;
                      mensaje.nom_respuesta := 'Error';
                      mensaje.des_Respuesta := g_lugar;
                      p_dat_mensaje         := mensaje;
               end if;
               end;
           END IF;
       END IF;
    else
        g_lugar := 'Referencia recibida distinta enviada' ||
        '- Recibida: '|| p_dat_cons_cas.nro_referencia||
        '- Buscada: '||v_nro_referencia;

        mensaje.cod_respuesta := 2;
        mensaje.nom_respuesta := 'Error';
        mensaje.des_Respuesta := g_lugar;
        p_dat_mensaje         := mensaje;
    end if;
end pr_pro_msj_rec_edi_cta;

 procedure pr_ins_ali_cas(p_dat_ali_cas  in out GE_SPI_ALI_CAS%ROWTYPE,
                          P_CANAL        in varchar2,
                          p_accion       in varchar2 default null) is
   v_nro_referencia  ge_spi_ali_cas.nro_referencia%type;
   V_clierecorid      ge_spi_ali_cas.cli_recordid%type;
   datosclie         GE_SPI_ALI_CAS%ROWTYPE;
   v_cod_circuito    WF_TIP_CIRCUITOS.COD_TIP_CIRCUITO%type;

   e_disponible exception ;
   v_sal_disponible number(18,2);
   V_cargo          number(10,2);

   v_cod_modulo           ge_cuentas.cod_modulo%type;
   v_cod_modalidad        ge_cuentas.cod_modalidad%type;
   v_cod_oficina          ge_cuentas.cod_oficina%type;
   v_cod_moneda           ge_cuentas.cod_moneda%type;
   v_tas_personalizada    ge_cuentas.tas_personalizada%type;

   v_cod_tas_cargo        ge_tasas.cod_tasa%type;
   v_val_tas_cargo        ge_movimientos.val_tasa%type := NULL;
   v_mto_cargo            ge_movimientos.monto%type    := 0;

   v_tra_debito        ge_movimientos.cod_transaccion%type ;

   v_tra_impuesto      ge_movimientos.cod_transaccion%type;
   v_cod_tas_impuesto  ge_tasas.cod_tasa%type;
   v_val_tas_impuesto  ge_movimientos.val_tasa%type := NULL;
   v_mto_impuesto      ge_movimientos.monto%type;

   v_tot_mto_cargo     ge_movimientos.monto%type    := 0;
 begin
    /*se controla que el modulo cas este activo para generar las consultas*/
    if FUG_OBT_PARDINAMICO('HAB_SPI_CAS') = 'S' then
       /*cobro de alta de alias*/

       if FUG_OBT_PARDINAMICO('CAS_COB_ALTA') = 'S' then
         v_cod_tas_cargo   := fue_obt_des_refcodes('SPI_CAR_CAS_ALI','COD_TASA');
         --v_tra_debito := fue_obt_des_refcodes('SPI_CAR_CAS_ALI','TRA_CARGO');
         v_tra_impuesto :=fue_obt_des_refcodes('SPI_CAR_CAS_ALI','TRA_IVA');
         if P_CANAL is not null then
           /*recupera datos de cuenta*/
             begin
              select g.cod_modulo,g.cod_modalidad,g.cod_oficina,g.cod_moneda,g.tas_personalizada
              into v_cod_modulo,v_cod_modalidad,v_cod_oficina,v_cod_moneda,v_tas_personalizada
              from ge_cuentas g
              where g.nro_cuenta= p_dat_ali_cas.nro_cta_solicitante;
             exception
             when no_data_found then
               v_cod_modulo := null;
               v_cod_modalidad := null;
               v_cod_oficina := null;
               v_cod_moneda := null;
               v_tas_personalizada := null;
             end;

           /*obtenemos monto cargo*/
           pr_obt_cargo(v_cod_oficina,p_dat_ali_cas.nro_cta_solicitante,v_cod_moneda,
           null,v_cod_modulo,v_cod_modalidad,nvl(v_tas_personalizada,'N'),
           null,v_cod_tas_cargo,v_val_tas_cargo,v_mto_cargo);

           v_tot_mto_cargo := v_tot_mto_cargo + nvl( v_mto_cargo,0 );
            /*Calculando Monto del Impuesto*/
           pr_obt_cargo(v_cod_oficina,p_dat_ali_cas.nro_cta_solicitante,v_cod_moneda,
           v_tot_mto_cargo,v_cod_modulo,v_cod_modalidad,nvl(v_tas_personalizada,'N'),
           v_tra_impuesto,v_cod_tas_impuesto,v_val_tas_impuesto,v_mto_impuesto);

          v_mto_impuesto := nvl( v_mto_impuesto, 0 );
          v_tot_mto_cargo := v_tot_mto_cargo + v_mto_impuesto;

           v_sal_disponible := fug_obt_sal_disp_atm(p_dat_ali_cas.nro_cta_solicitante);

           if v_sal_disponible < v_tot_mto_cargo then
              raise e_disponible;
           end if  ;
         end if;
       end if;

      v_nro_referencia:=pas_cas.fu_obt_sig_ref_cas;

      if p_dat_ali_cas.cod_persona is not null  then
           begin
             select c.cli_recordid
             into V_clierecorid
             from ge_spi_cli_cas c
             where c.cod_persona = p_dat_ali_cas.cod_persona
             and c.est_solicitud='A';
            exception
              when no_data_found then
               V_clierecorid := null;
              when too_many_rows then
                 V_clierecorid := null;
           end;
       else
          V_clierecorid := null;
       end if;


       begin
         insert into GE_SPI_ALI_CAS (nro_referencia,tip_identificador,val_identificador,cod_persona,fec_registro,
             fec_ven_registro,nro_cta_solicitante,est_alias,est_solicitud,cli_recordid,
             ali_recordid,cue_recordid,cta_por_defecto,ERROR,TIP_ACCION )
         values (v_nro_referencia, p_dat_ali_cas.tip_identificador,p_dat_ali_cas.val_identificador,
              p_dat_ali_cas.cod_persona,p_dat_ali_cas.fec_registro, p_dat_ali_cas.fec_ven_registro,
              p_dat_ali_cas.nro_cta_solicitante,'active',p_dat_ali_cas.est_solicitud,
              V_clierecorid,p_dat_ali_cas.ali_recordid,p_dat_ali_cas.cue_recordid,
              p_dat_ali_cas.cta_por_defecto,null,p_accion);
         if sql%rowcount > 0 then
            if P_CANAL is null then
              v_cod_circuito:= fug_obt_pardinamico('PAS_CAS_CIR_ALTA_ALI');
              if paw_cir.fu_ini_circuito( v_cod_circuito,v_nro_referencia,  p_dat_ali_cas.cod_persona ) <> 0 then
                pas_cas.g_cod_error := 50;
                pas_cas.g_msj_error := 'No se ha podido iniciar el circuito ' || 160 ||'. '|| nvl( paw_cir.fu_obt_msj_error, sqlerrm );
              else
                datosclie.nro_referencia := v_nro_referencia;
                p_dat_ali_cas            :=datosclie;
              end if;
           else
                datosclie.nro_referencia := v_nro_referencia;
                p_dat_ali_cas            :=datosclie;
           end if;
         else
           pas_cas.g_msj_error := 'Error al registrar alta de Alias de cliente '||sqlerrm;
          pas_cas.g_cod_error := 1;
         end if;
       end;

    elsif  FUG_OBT_PARDINAMICO('HAB_SPI_CAS') = 'N' then
     /*si el parametro esta en N no genera ni una solicitud de consulta*/
     pas_cas.g_msj_error := 'El módulo CAS no se encuentra habilitado.';
     pas_cas.g_cod_error := 30;
    end if;
EXCEPTION
  when e_disponible then
    pas_cas.g_cod_error := 20;
    pas_cas.g_msj_error := 'No se puede generar la solicitud. Saldo insuficiente';
 WHEN OTHERS THEN
    pas_cas.g_msj_error := 'Ocurrio un error. '||sqlerrm;
    pas_cas.g_cod_error := 1;
 end pr_ins_ali_cas;

 procedure pr_obt_dat_ali_cas(p_dat_cab_cons_cas out typ_ObtdatCabconcas,
                             p_dat_cons_cas     out typ_ObtRegalicas,
                              p_dat_mensaje     out typ_mensajeria_spi) is

 v_nro_referencia  GE_SPI_ALI_CAS.nro_referencia%type;
 datosali          typ_ObtRegalicas;
 mensaje           typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);

 cursor dat_ali is
 select nro_referencia ,
       c.cli_recordid,
       tip_identificador ,
       val_identificador,
       fec_registro ,
       fec_ven_registro ,
       nro_cta_solicitante ,
       est_alias,
       tip_accion
  from ge_spi_ali_cas c
  where est_solicitud = 'U'
  AND ROWNUM=1
  order by  nro_referencia
  for update skip locked;

 begin
      begin
        pre_ini_aplicacion;
        pae_cnf.g_cod_modulo := 1;
      end;
    g_lugar:= 'Recorre solicitudes';
    for i in  dat_ali loop
        v_nro_referencia:=i.nro_referencia;
        g_lugar:='Registro de parametros en log ';

        datosali := typ_ObtRegalicas(i.nro_referencia,i.cli_recordid ,i.tip_identificador, i.val_identificador,
                                     i.fec_registro, i.fec_ven_registro, i.nro_cta_solicitante ,
                                     i.est_alias,i.tip_accion);
        g_lugar:='Registro de parametros en log ';
        pas_cas.pr_reg_operacion( 'nro_referencia: '      ||    i.nro_referencia     || chr(10)||
                                  'cli_recorid: '         ||    i.cli_recordid         || chr(10)||
                                  'tip_identificador: '   ||    i.tip_identificador   || chr(10)||
                                  'val_identificador: '   ||    i.val_identificador   || chr(10)||
                                  'fec_registro: '        ||    i.fec_registro        || chr(10)||
                                  'fec_ven_registro: '    ||    i.fec_ven_registro    || chr(10)||
                                  'nro_cta_solicitante: ' ||    i.nro_cta_solicitante || chr(10)||
                                  'est_alias: '           ||    i.est_alias           || chr(10)||
                                  'tip_accion: '          ||    i.tip_accion,         g_lugar||
                                  'nro_referencia: '      ||    i.nro_referencia);
    end loop;
  if v_nro_referencia is not null then
      g_lugar:='Asigna datos para la cabecera';

      p_dat_cab_cons_cas :=PAS_CAS.fu_obt_dat_Cab_concas(v_nro_referencia);

      g_lugar:='Actualizacion de Registro a bloqueado';
    begin
         UPDATE GE_SPI_ALI_CAS
         SET Est_solicitud = 'B'
         WHERE nro_referencia = v_nro_referencia;
       if sql%rowcount > 0 then
          p_dat_cons_cas := datosali;
          p_dat_mensaje   := mensaje;
       else
        mensaje.cod_respuesta := 1;
        mensaje.nom_respuesta := 'Error';
        mensaje.des_Respuesta := 'Error al bloquear registro';
        p_dat_cons_cas        := datosali;
        p_dat_mensaje         := mensaje;
        end if;
    end;
   else
    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Sin registros';
    mensaje.des_Respuesta := 'No existe registro a consultar';
    p_dat_cons_cas        := datosali;
    p_dat_mensaje         := mensaje;
    end if;
 exception
   when others then
     mensaje.cod_respuesta := 1;
        mensaje.nom_respuesta := 'Error';
        mensaje.des_Respuesta := 'Ocurrio un error. '||sqlerrm;
        p_dat_cons_cas        := datosali;
        p_dat_mensaje         := mensaje;
 end pr_obt_dat_ali_cas ;

  procedure pr_pro_msj_rec_ali_cas(p_dat_ali_cas    in typ_obtdatresali,
                                   p_dat_mensaje     out typ_mensajeria_spi) is

  v_nro_referencia       GE_SPI_ALI_CAS.NRO_REFERENCIA%type;
  v_tip_identificador    ge_spi_ali_cas.tip_identificador%type;
  v_val_identificador    ge_spi_ali_cas.val_identificador%type;
  v_fec_ini              ge_spi_ali_cas.fec_registro%type;
  v_cod_persona          ge_spi_ali_cas.cod_persona%type;
  mensaje                typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);
  v_descripcion_error    varchar2(200);
  v_inf_json             long:=null;

  r_det                  GE_SPI_ALI_CAS%ROWTYPE;
  begin
        begin
          pre_ini_aplicacion;
          pae_cnf.g_cod_modulo := 1;
        end;
      pas_cas.pr_ini_variables;
         g_lugar := 'Registro de parametros en log';
          pas_cas.pr_reg_operacion('Parametros=> Nro_referencia:'|| p_dat_ali_cas.nro_referencia || chr(10) ||
                                   'ali_recordID: '               || p_dat_ali_cas.ali_recordID || chr(10)  ||
                                   'Est_alias: '                  || p_dat_ali_cas.est_alias    || chr(10)    ||
                                   'Error: '                      || p_dat_ali_cas.error        || chr(10)    ||
                                   'Tip_Accion: '                 || p_dat_ali_cas.tip_accion ,
                                    g_lugar|| ' Nro_referencia: ' || p_dat_ali_cas.nro_referencia);
   g_lugar := 'Valida referencia';
       begin
        select c.nro_referencia,c.tip_identificador,c.val_identificador,c.fec_registro,c.cod_persona
        into v_nro_referencia,v_tip_identificador,v_val_identificador,v_fec_ini,v_cod_persona
        from ge_spi_ali_cas c
        where c.nro_referencia= p_dat_ali_cas.nro_referencia;
       exception
         when no_data_found then
         v_nro_referencia := null;

         when others then
           g_lugar := 'Error al recuperar nro_referencia'||'-'|| p_dat_ali_cas.nro_referencia;
           mensaje.cod_respuesta := 1;
           mensaje.nom_respuesta := 'Error';
           mensaje.des_Respuesta := g_lugar;
           p_dat_mensaje         := mensaje;
      end;

     if v_nro_referencia = p_dat_ali_cas.nro_referencia then
       if p_dat_ali_cas.error is null then
         g_lugar := 'Actualizar ge_spi_ali_cas';
         begin
           update ge_spi_ali_cas c
           set c.ali_recordid    = p_dat_ali_cas.ali_recordID,
               c.est_solicitud   = 'A'
           where c.nro_referencia = p_dat_ali_cas.nro_referencia;

          if sql%rowcount > 0 then
            v_inf_json:='{'||'"nombre":'      ||'"'||FUE_OBT_NOM_PERSONA(v_cod_persona)||'"'||','||
                             '"tip_documento":'   ||'"'||v_tip_identificador           ||'"'||','||
                             '"nro_documento":' ||'"'||v_val_identificador             ||'"'||','||
                             '"fec_inicio":'    ||'"'||to_char(v_fec_ini, 'DD/MM/YYYY')||'"'||','||
                             '"est_alias":'     ||'"'||p_dat_ali_cas.est_alias  ||'"' || '}';

            if p_dat_ali_cas.tip_accion is null  then
                if fu_obt_tip_per(v_cod_persona) = 'F' then
                    pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTCAL'),v_inf_json);
                    p_dat_mensaje         := mensaje;
                elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                    pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTCALOJ'),v_inf_json);
                    p_dat_mensaje         := mensaje;
                else
                    p_dat_mensaje         := mensaje;
                end if;
            elsif p_dat_ali_cas.tip_accion= 'E' or p_dat_ali_cas.tip_accion = 'A'  then
               /* cuando el alta en un solo paso es posterior a la edicion se llama al procedure
               pr_edi_ali_cas el parametro de p_canal debe ser WEB + el tipo de accion 'E' EDICION
               si la llamada se hace para dar de alta una cuenta nueva el p_canal debe ser WEB + 'A' */

               begin
                  begin
                    select c.nro_referencia, c.tip_identificador,c.val_identificador,
                           c.cod_persona, c.fec_registro, c.fec_ven_registro, c.nro_cta_solicitante,
                           c.est_alias, c.est_solicitud, c.cli_recordid, c.ali_recordid, c.cue_recordid,
                           c.cta_por_defecto
                    into r_det.nro_referencia, r_det.tip_identificador, r_det.val_identificador,
                         r_det.cod_persona, r_det.fec_registro,  r_det.fec_ven_registro,
                         r_det.nro_cta_solicitante, r_det.est_alias, r_det.est_solicitud,
                         r_det.cli_recordid, r_det.ali_recordid,  r_det.cue_recordid,
                         r_det.cta_por_defecto
                    from ge_spi_ali_cas c
                    where c.nro_referencia= p_dat_ali_cas.nro_referencia;

                   exception
                     when no_data_found then
                       g_lugar := 'Error al vincular cuenta con alias'||'-'|| p_dat_ali_cas.nro_referencia;
                       mensaje.cod_respuesta := 1;
                       mensaje.nom_respuesta := 'Error';
                       mensaje.des_Respuesta := g_lugar;
                       p_dat_mensaje         := mensaje;

                     when others then
                       g_lugar := 'Error al vincular cuenta con alias'||'-'|| p_dat_ali_cas.nro_referencia;
                       mensaje.cod_respuesta := 1;
                       mensaje.nom_respuesta := 'Error';
                       mensaje.des_Respuesta := g_lugar;
                       p_dat_mensaje         := mensaje;
                  end;
                  if p_dat_ali_cas.tip_accion= 'E' then
                    pas_Cas.pr_edi_ali_cas(r_det,'VIN','WEBE');
                  elsif p_dat_ali_cas.tip_accion= 'A'  then
                      pas_Cas.pr_edi_ali_cas(r_det,'VIN','WEBA');
                  end if;
               end;
            end if;
           else
             mensaje.cod_respuesta := 3;
              mensaje.nom_respuesta := 'Error';
              mensaje.des_Respuesta := g_lugar;
              p_dat_mensaje         := mensaje;
           end if;
         end;
       else
         v_descripcion_error:=fue_obt_des_refcodes('TIP_REC_CAS',p_dat_ali_cas.error) ;
          g_lugar := 'Actualizar error ge_spi_cli_cas';
          begin
            update ge_spi_ali_cas c
               set c.est_solicitud       = 'E',
                   c.error               = p_dat_ali_cas.error||' '||v_descripcion_error
               where c.nro_referencia= p_dat_ali_cas.nro_referencia;
            if sql%rowcount > 0 then
              v_inf_json:='{'||'"nombre":'      ||'"'||FUE_OBT_NOM_PERSONA(v_cod_persona) ||'"'||','||
                               '"tip_documento":' ||'"'||v_tip_identificador      ||'"'||','||
                               '"nro_documento":' ||'"'||v_val_identificador      ||'"'||','||
                               '"fec_inicio":'    ||'"'||to_char(v_fec_ini, 'DD/MM/YYYY')  ||'"'||','||
                               '"est_alias":'     ||'"'||p_dat_ali_cas.est_alias  ||'"'||','||
                               '"Error":'         ||'"'||v_descripcion_error      ||'"'||'}';
                if p_dat_ali_cas.tip_accion is null  then
                      if fu_obt_tip_per(v_cod_persona) = 'F' then
                          pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTCAL'),v_inf_json);
                          p_dat_mensaje         := mensaje;
                      elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                          pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTCNALPJ'),v_inf_json);
                          p_dat_mensaje         := mensaje;
                      else
                          p_dat_mensaje         := mensaje;
                      end if;
                elsif p_dat_ali_cas.tip_accion= 'E'  then
                  /*notificacion de edicion desde web si no es exito*/
                   if fu_obt_tip_per(v_cod_persona) = 'F' then
                          --pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTEDN1SP'),v_inf_json);--TCE-249 tipo prod 139
                          p_dat_mensaje         := mensaje;
                      elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                          pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTEDN1SPPJ'),v_inf_json);
                          p_dat_mensaje         := mensaje;
                      else
                          p_dat_mensaje         := mensaje;
                      end if;
                elsif p_dat_ali_cas.tip_accion= 'A' then
                  /*notificacion de alta desde web si no es exito*/
                   if fu_obt_tip_per(v_cod_persona) = 'F' then
                          --pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTN1SP'),v_inf_json);--TCE-249 tipo prod 142
                          p_dat_mensaje         := mensaje;
                      elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                          pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTN1SPPJ'),v_inf_json);
                          p_dat_mensaje         := mensaje;
                      else
                          p_dat_mensaje         := mensaje;
                      end if;
                end if;
           else
            mensaje.cod_respuesta := 3;
              mensaje.nom_respuesta := 'Error';
              mensaje.des_Respuesta := g_lugar;
              p_dat_mensaje         := mensaje;
           end if;
          end;

       end if;
     else
        g_lugar := 'Referencia recibida distinta enviada' ||
      '- Recibida: '|| p_dat_ali_cas.nro_referencia||
      '- Buscada: '||v_nro_referencia;

      mensaje.cod_respuesta := 2;
      mensaje.nom_respuesta := 'Error';
      mensaje.des_Respuesta := g_lugar;
      p_dat_mensaje         := mensaje;
    end if;
exception
  when others then
   mensaje.cod_respuesta := 1;
   mensaje.nom_respuesta := 'Error';
   mensaje.des_Respuesta := sqlerrm;
   p_dat_mensaje         := mensaje;
end pr_pro_msj_rec_ali_cas;

 procedure pr_edi_ali_cas(p_dat_ali_cas in out GE_SPI_ALI_CAS%ROWTYPE,
                          p_accion      in varchar2,
                          p_canal       in varchar2 default null) is

  v_nro_referencia  ge_spi_ali_cas.nro_referencia%type;
  v_cod_persona     ba_personas.cod_persona%type;
  v_tip_acccion     varchar2(30);
  v_est_alias       varchar2(20);
  v_est_solicitud   varchar2(1);
  v_canal           varchar2(4) default null;
  datosclie         GE_SPI_ALI_CAS%ROWTYPE;
  v_cod_circuito    WF_TIP_CIRCUITOS.COD_TIP_CIRCUITO%type;

  e_disponible exception ;
   v_sal_disponible number(18,2);
   V_cargo          number(10,2);

   v_cod_modulo           ge_cuentas.cod_modulo%type;
   v_cod_modalidad        ge_cuentas.cod_modalidad%type;
   v_cod_oficina          ge_cuentas.cod_oficina%type;
   v_cod_moneda           ge_cuentas.cod_moneda%type;
   v_tas_personalizada    ge_cuentas.tas_personalizada%type;

   v_cod_tas_cargo        ge_tasas.cod_tasa%type;
   v_val_tas_cargo        ge_movimientos.val_tasa%type := NULL;
   v_mto_cargo            ge_movimientos.monto%type    := 0;

   v_tra_debito        ge_movimientos.cod_transaccion%type ;

   v_tra_impuesto      ge_movimientos.cod_transaccion%type;
   v_cod_tas_impuesto  ge_tasas.cod_tasa%type;
   v_val_tas_impuesto  ge_movimientos.val_tasa%type := NULL;
   v_mto_impuesto      ge_movimientos.monto%type;

   v_tot_mto_cargo     ge_movimientos.monto%type    := 0;
  begin
     /*se controla que el modulo cas este activo para generar las consultas*/
    if FUG_OBT_PARDINAMICO('HAB_SPI_CAS') = 'S' then
       if FUG_OBT_PARDINAMICO('CAS_COB_ALTA') = 'S' then
         v_cod_tas_cargo   := fue_obt_des_refcodes('SPI_CAR_CAS_ALI','COD_TASA');
         --v_tra_debito := fue_obt_des_refcodes('SPI_CAR_CAS_ALI','TRA_CARGO');
         v_tra_impuesto :=fue_obt_des_refcodes('SPI_CAR_CAS_ALI','TRA_IVA');

           /*recupera datos de cuenta*/
             begin
              select g.cod_modulo,g.cod_modalidad,g.cod_oficina,g.cod_moneda,g.tas_personalizada
              into v_cod_modulo,v_cod_modalidad,v_cod_oficina,v_cod_moneda,v_tas_personalizada
              from ge_cuentas g
              where g.nro_cuenta= p_dat_ali_cas.nro_cta_solicitante;
             exception
             when no_data_found then
               v_cod_modulo := null;
               v_cod_modalidad := null;
               v_cod_oficina := null;
               v_cod_moneda := null;
               v_tas_personalizada := null;
             end;

           /*obtenemos monto cargo*/
           pr_obt_cargo(v_cod_oficina,p_dat_ali_cas.nro_cta_solicitante,v_cod_moneda,
           null,v_cod_modulo,v_cod_modalidad,nvl(v_tas_personalizada,'N'),
           null,v_cod_tas_cargo,v_val_tas_cargo,v_mto_cargo);

           v_tot_mto_cargo := v_tot_mto_cargo + nvl( v_mto_cargo,0 );
            /*Calculando Monto del Impuesto*/
           pr_obt_cargo(v_cod_oficina,p_dat_ali_cas.nro_cta_solicitante,v_cod_moneda,
           v_tot_mto_cargo,v_cod_modulo,v_cod_modalidad,nvl(v_tas_personalizada,'N'),
           v_tra_impuesto,v_cod_tas_impuesto,v_val_tas_impuesto,v_mto_impuesto);

          v_mto_impuesto := nvl( v_mto_impuesto, 0 );
          v_tot_mto_cargo := v_tot_mto_cargo + v_mto_impuesto;

           v_sal_disponible := fug_obt_sal_disp_atm(p_dat_ali_cas.nro_cta_solicitante);
          if  p_canal is not null and p_accion <> 'VIN' THEN
             if v_sal_disponible < v_tot_mto_cargo then
                raise e_disponible;
             end if  ;
           elsif p_canal is null then
             if v_sal_disponible < v_tot_mto_cargo then
                raise e_disponible;
             end if  ;
           end if;
       end if;

     v_nro_referencia:= pas_cas.fu_obt_sig_ref_cas;

      if p_accion ='VIN' THEN
       v_tip_acccion:='Vinculación de Cta.';
       v_est_alias := p_dat_ali_cas.EST_ALIAS;
     elsif p_accion ='DES' THEN

        v_tip_acccion:='Desvinculación de Cta.';
        v_est_alias := p_dat_ali_cas.EST_ALIAS;
     elsif p_accion ='UPD'THEN

        v_tip_acccion:='Actualización';
        v_est_alias := p_dat_ali_cas.EST_ALIAS;
     elsif p_accion ='ACT'THEN

        v_tip_acccion:='Activacion';
        v_est_alias:='active';
     elsif p_accion ='SUS'THEN

        v_tip_acccion:='Suspension';
        v_est_alias:='suspended';

     elsif p_accion ='ELI'THEN

        v_tip_acccion:='Eliminación';
        v_est_alias  := p_dat_ali_cas.EST_ALIAS  ;
     END IF;

       if p_canal is null then
          /*viende desde itgf*/
          v_est_solicitud := 'P';
       else
          /*viende desde web*/
          v_est_solicitud := 'U';
          --v_canal :='WEB';
       end if;

        Begin
           insert into GE_SPI_ALI_CAS_TMP(NRO_REFERENCIA, TIP_IDENTIFICADOR, VAL_IDENTIFICADOR, COD_PERSONA,
                  FEC_REGISTRO,FEC_VEN_REGISTRO,NRO_CTA_SOLICITANTE,EST_ALIAS,EST_SOLICITUD,
                  CLI_RECORDID,ALI_RECORDID, CUE_RECORDID,CTA_POR_DEFECTO, ERROR,TIP_ACCION,TIP_CANAL)
          VALUES (v_nro_referencia, p_dat_ali_cas.TIP_IDENTIFICADOR, p_dat_ali_cas.VAL_IDENTIFICADOR,
                 p_dat_ali_cas.COD_PERSONA, p_dat_ali_cas.FEC_REGISTRO,p_dat_ali_cas.FEC_VEN_REGISTRO,
                 p_dat_ali_cas.NRO_CTA_SOLICITANTE,v_est_alias,v_est_solicitud,
                  p_dat_ali_cas.CLI_RECORDID,p_dat_ali_cas.ALI_RECORDID, p_dat_ali_cas.CUE_RECORDID,
                  p_dat_ali_cas.CTA_POR_DEFECTO, p_dat_ali_cas.ERROR,p_accion,p_canal);
           if sql%rowcount > 0 then
               IF P_CANAL IS NULL THEN

                  IF p_accion ='VIN' THEN
                    v_cod_circuito:= fug_obt_pardinamico('PAS_CAS_CIR_VIN_ALI');
                    if paw_cir.fu_ini_circuito( v_cod_circuito,v_nro_referencia, p_dat_ali_cas.cod_persona ) <> 0 then
                      pas_cas.g_cod_error := 50;
                      pas_cas.g_msj_error := 'No se ha podido iniciar el circuito ' || 157 ||'. '|| nvl( paw_cir.fu_obt_msj_error, sqlerrm );
                    else
                      datosclie.nro_referencia := v_nro_referencia;
                      p_dat_ali_cas            :=datosclie;
                    end if;
                 ELSIF p_accion ='DES' THEN
                   v_cod_circuito:= fug_obt_pardinamico('PAS_CAS_CIR_DES_ALI');
                       if paw_cir.fu_ini_circuito(v_cod_circuito,v_nro_referencia, p_dat_ali_cas.cod_persona ) <> 0 then
                          pas_cas.g_cod_error := 50;
                          pas_cas.g_msj_error := 'No se ha podido iniciar el circuito ' || 158 ||'. '|| nvl( paw_cir.fu_obt_msj_error, sqlerrm );
                      else
                          datosclie.nro_referencia := v_nro_referencia;
                          p_dat_ali_cas            :=datosclie;
                       end if;
                 ELSIF p_accion ='UPD' THEN
                   v_cod_circuito:= fug_obt_pardinamico('PAS_CAS_CIR_UPD_ALI');
                       if paw_cir.fu_ini_circuito( v_cod_circuito,v_nro_referencia, p_dat_ali_cas.cod_persona ) <> 0 then
                        pas_cas.g_cod_error := 50;
                        pas_cas.g_msj_error := 'No se ha podido iniciar el circuito ' || 159 ||'. '|| nvl( paw_cir.fu_obt_msj_error, sqlerrm );
                       else
                          datosclie.nro_referencia := v_nro_referencia;
                          p_dat_ali_cas            :=datosclie;
                       end if;
                 ELSIF p_accion ='ACT' THEN
                   v_cod_circuito:= fug_obt_pardinamico('PAS_CAS_CIR_ACT_ALI');
                       if paw_cir.fu_ini_circuito( v_cod_circuito,v_nro_referencia, p_dat_ali_cas.cod_persona ) <> 0 then
                        pas_cas.g_cod_error := 50;
                        pas_cas.g_msj_error := 'No se ha podido iniciar el circuito ' || 159 ||'. '|| nvl( paw_cir.fu_obt_msj_error, sqlerrm );
                       else
                          datosclie.nro_referencia := v_nro_referencia;
                          p_dat_ali_cas            :=datosclie;
                       end if;
                 ELSIF p_accion ='SUS' THEN
                   v_cod_circuito:= fug_obt_pardinamico('PAS_CAS_CIR_SUS_ALI');
                       if paw_cir.fu_ini_circuito( v_cod_circuito,v_nro_referencia, p_dat_ali_cas.cod_persona ) <> 0 then
                        pas_cas.g_cod_error := 50;
                        pas_cas.g_msj_error := 'No se ha podido iniciar el circuito ' || 159 ||'. '|| nvl( paw_cir.fu_obt_msj_error, sqlerrm );
                      else
                          datosclie.nro_referencia := v_nro_referencia;
                          p_dat_ali_cas            :=datosclie;
                       end if;
                 ELSIF p_accion ='ELI' THEN
                   v_cod_circuito:= fug_obt_pardinamico('PAS_CAS_CIR_ELI_ALI');
                       if paw_cir.fu_ini_circuito( v_cod_circuito,v_nro_referencia, p_dat_ali_cas.cod_persona ) <> 0 then
                        pas_cas.g_cod_error := 50;
                        pas_cas.g_msj_error := 'No se ha podido iniciar el circuito ' || 159 ||'. '|| nvl( paw_cir.fu_obt_msj_error, sqlerrm );
                       else
                          datosclie.nro_referencia := v_nro_referencia;
                          p_dat_ali_cas            :=datosclie;
                       end if;
                 END IF;
               END IF;
           else
               pas_cas.g_msj_error := 'Error al registrar la '||v_tip_acccion||'del cliente '||sqlerrm;
               pas_cas.g_cod_error := 1;
           end if;
        end;

      elsif  FUG_OBT_PARDINAMICO('HAB_SPI_CAS') = 'N' then
       /*si el parametro esta en N no genera ni una solicitud de consulta*/
       pas_cas.g_msj_error := 'El módulo CAS no se encuentra habilitado.';
       pas_cas.g_cod_error := 30;
      end if;
exception
  when e_disponible then
    pas_cas.g_cod_error := 20;
    pas_cas.g_msj_error := 'No se puede generar la solicitud. Saldo insuficiente';
  when others then
   pas_cas.g_msj_error := 'Ocurrio un error. '||sqlerrm;
   pas_cas.g_cod_error := 1;
 end pr_edi_ali_cas;

 procedure pr_obt_edi_ali_cas (p_dat_cab_cons_cas out typ_ObtdatCabconcas,
                                p_dat_ali_cas    out typ_obtedialicas,
                                p_dat_mensaje     out typ_mensajeria_spi) is

  v_nro_referencia  ge_spi_ali_cas_tmp.nro_referencia%type:=null;
  v_tip_accion      ge_spi_ali_cas_tmp.tip_accion%type:=null;
  datosclie         typ_obtedialicas;
  mensaje           typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);

 cursor edi_ali is
 select nro_referencia,
       ali_recordID,
       cue_recordID,
       nro_cta_solicitante,
       cta_por_defecto,
       t.est_alias,
       fec_ven_registro,
       t.tip_accion,
       error,
       TIP_CANAL
  from ge_spi_ali_cas_tmp t
 where t.est_solicitud = 'U'
 AND ROWNUM=1
 order by t.nro_referencia asc
  for update skip locked;
 begin
    begin
        pre_ini_aplicacion;
        pae_cnf.g_cod_modulo := 1;
      end;
      g_lugar := 'Recorremos registros';
      for i in  edi_ali loop
        v_nro_referencia:= i.nro_referencia;
        v_tip_accion:=i.tip_accion;

        datosclie:= typ_obtedialicas(i.nro_referencia,i.ali_recordid,i.cue_recordid,
        i.nro_cta_solicitante,i.cta_por_defecto,i.est_alias,i.fec_ven_registro,i.tip_accion,i.error,i.tip_canal);
        g_lugar:='Registro de parametros en log ';
         pas_cas.pr_reg_operacion('Nro_referencia: '       ||i.nro_referencia      || chr(10) ||
                                  ' ali_recordid: '        ||i.ali_recordid        || chr(10) ||
                                  ' cue_recordid: '        ||i.cue_recordid        || chr(10) ||
                                  ' nro_cta_solicitante: ' ||i.nro_cta_solicitante || chr(10) ||
                                  ' cta_por_defecto: '     ||i.cta_por_defecto     || chr(10) ||
                                  ' Est_alias: '           ||i.est_alias           || chr(10) ||
                                  ' tip_accion: '          ||i.tip_accion          || chr(10) ||
                                  ' error: '               ||i.error               || chr(10) ||
                                  ' Canal: '               ||i.TIP_CANAL,          g_lugar   ||
                                  ' Nro_referencia: '   ||i.nro_referencia );

      end loop;

    if  v_nro_referencia is not null then
      g_lugar:='Asigna datos para la cabecera';

      p_dat_cab_cons_cas :=PAS_CAS.fu_obt_dat_Cab_concas(v_nro_referencia);

      g_lugar:='Actualizacion de cliente a bloqueado';
      BEGIN
         UPDATE ge_spi_ali_cas_tmp
         SET Est_solicitud = 'B'
         WHERE nro_referencia = v_nro_referencia
         and tip_accion=v_tip_accion;
       if sql%rowcount > 0 then
         p_dat_ali_cas := datosclie;
         p_dat_mensaje   := mensaje;
      else
          mensaje.cod_respuesta := 1;
          mensaje.nom_respuesta := 'Error';
          mensaje.des_Respuesta := 'Error al bloquear Registro';

          p_dat_ali_cas         := datosclie;
          p_dat_mensaje         := mensaje;
      end if;
      END;
    else
       mensaje.cod_respuesta := 1;
      mensaje.nom_respuesta := 'Sin registros';
      mensaje.des_Respuesta := 'No existe registro a consultar';
      p_dat_ali_cas         := datosclie;
      p_dat_mensaje         := mensaje;
    end if;
  exception
    when others then
      mensaje.cod_respuesta := 1;
      mensaje.nom_respuesta := 'Error';
      mensaje.des_Respuesta := 'Ocurrio un error. '|| sqlerrm;
      p_dat_ali_cas         := datosclie;
      p_dat_mensaje         := mensaje;
 end pr_obt_edi_ali_cas;

 procedure pr_pro_msj_rec_edi_ali(p_dat_ali_cas   in typ_obtedialicas,
                                  p_dat_mensaje   out typ_mensajeria_spi)is


 mensaje               typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);
 v_nro_referencia      GE_SPI_ali_CAS.Nro_Referencia%type;
 v_cod_persona          GE_SPI_ali_CAS.COD_PERSONA%type;
 v_tip_identificador    GE_SPI_ali_CAS.TIP_IDENTIFICADOR%type;
 v_val_identificador    GE_SPI_ali_CAS.val_IDENTIFICADOR%type;
 v_fec_registro         ge_spi_ali_cas.fec_registro%type;
 v_estado_alias         ge_spi_ali_cas.est_alias%type;
 v_descripcion_error     varchar2(100);
 v_inf_json              long:=null;
 v_tipo_per              varchar2(1);
 v_cta_recordid          GE_SPI_ali_CAS.Cue_Recordid%type;
 v_cli_recordid          GE_SPI_cli_CAS.Cli_Recordid%type;

 rg_cta_cliente          pag_cta.rg_ctas;
 v_nro_secuencia     ge_movimientos.nro_secuencia%type   := 0;

 v_sal_disponible number(18,2);


 v_cod_tas_cargo        ge_tasas.cod_tasa%type;
 v_val_tas_cargo        ge_movimientos.val_tasa%type := NULL;
 v_mto_cargo            ge_movimientos.monto%type    := 0;

 v_tra_debito        ge_movimientos.cod_transaccion%type ;

 v_tra_impuesto      ge_movimientos.cod_transaccion%type;
 v_cod_tas_impuesto  ge_tasas.cod_tasa%type;
 v_val_tas_impuesto  ge_movimientos.val_tasa%type := NULL;
 v_mto_impuesto      ge_movimientos.monto%type;

 v_tot_mto_cargo     ge_movimientos.monto%type    := 0;
 begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;

  pas_cas.pr_ini_variables;
    g_lugar := 'Registro de parametros en log';
    pas_cas.pr_reg_operacion('Nro_referencia: '        ||p_dat_ali_cas.nro_referencia      || chr(10) ||
                              ' ali_recordid: '        ||p_dat_ali_cas.ali_recordid        || chr(10) ||
                              ' cue_recordid: '        ||p_dat_ali_cas.cue_recordid        || chr(10) ||
                              ' nro_cta_solicitante: ' ||p_dat_ali_cas.nro_cta_solicitante || chr(10) ||
                              ' cta_por_defecto: '     ||p_dat_ali_cas.cta_por_defecto     || chr(10) ||
                              ' Est_alias: '           ||p_dat_ali_cas.est_alias           || chr(10) ||
                              ' tip_accion: '          ||p_dat_ali_cas.tip_edicion         || chr(10) ||
                              ' error: '               ||p_dat_ali_cas.error               || chr(10) ||
                              ' Canal: '               ||p_dat_ali_cas.canal,  g_lugar     ||
                              ' Nro_referencia: '   ||p_dat_ali_cas.nro_referencia );

   if FUG_OBT_PARDINAMICO('CAS_COB_ALTA') = 'S' then
      v_cod_tas_cargo   := fue_obt_des_refcodes('SPI_CAR_CAS_ALI','COD_TASA');
      --v_tra_debito := fue_obt_des_refcodes('SPI_CAR_CAS_ALI','TRA_CARGO');
      v_tra_impuesto :=fue_obt_des_refcodes('SPI_CAR_CAS_ALI','TRA_IVA');
    /*recupera datos de cuenta*/
      begin
       select g.nro_cuenta, g.cod_modulo,g.cod_modalidad,g.cod_oficina,g.cod_moneda,nvl(g.tas_personalizada,'N')
       into rg_cta_cliente.NRO_CUENTA,rg_cta_cliente.COD_MODULO,rg_cta_cliente.COD_MODALIDAD,rg_cta_cliente.COD_OFICINA,
       rg_cta_cliente.COD_MONEDA, rg_cta_cliente.TAS_PERSONALIZADA
       from ge_cuentas g
       where g.nro_cuenta= p_dat_ali_cas.nro_cta_solicitante;
      exception
      when no_data_found then
         rg_cta_cliente.COD_MODULO        := null;
         rg_cta_cliente.COD_MODALIDAD     := null;
         rg_cta_cliente.COD_OFICINA       := null;
         rg_cta_cliente.COD_MONEDA        := null;
         rg_cta_cliente.TAS_PERSONALIZADA := null;
       end;
        /*obtenemos monto cargo*/
           pr_obt_cargo(rg_cta_cliente.COD_OFICINA,p_dat_ali_cas.nro_cta_solicitante,rg_cta_cliente.COD_MONEDA,
           null,rg_cta_cliente.COD_MODULO,rg_cta_cliente.COD_MODALIDAD,rg_cta_cliente.TAS_PERSONALIZADA,
           null,v_cod_tas_cargo,v_val_tas_cargo,v_mto_cargo);

           v_tot_mto_cargo := v_tot_mto_cargo + nvl( v_mto_cargo,0 );
            /*Calculando Monto del Impuesto*/
           pr_obt_cargo(rg_cta_cliente.COD_OFICINA,p_dat_ali_cas.nro_cta_solicitante,rg_cta_cliente.COD_MONEDA,
           v_tot_mto_cargo,rg_cta_cliente.COD_MODULO,rg_cta_cliente.COD_MODALIDAD,rg_cta_cliente.TAS_PERSONALIZADA,
           v_tra_impuesto,v_cod_tas_impuesto,v_val_tas_impuesto,v_mto_impuesto);

          v_mto_impuesto := nvl( v_mto_impuesto, 0 );
          v_tot_mto_cargo := v_tot_mto_cargo + v_mto_impuesto;

           v_sal_disponible := fug_obt_sal_disp_atm(p_dat_ali_cas.nro_cta_solicitante);

           if v_sal_disponible < v_tot_mto_cargo then
              g_car_ali :='N';
           else
              g_car_ali := 'S';
           end if  ;
   end if;

   begin
        select c.nro_referencia, c.tip_identificador,c.val_identificador,
               c.cod_persona,c.fec_registro,c.est_alias
        into v_nro_referencia,v_tip_identificador ,v_val_identificador,
             v_cod_persona,v_fec_registro,v_estado_alias
        from ge_spi_ali_cas_tmp c
        where c.nro_referencia  =   p_dat_ali_cas.nro_referencia
        and c.tip_accion        =  p_dat_ali_cas.tip_edicion;
    exception
         when no_data_found then
         v_nro_referencia        := null;
         v_val_identificador     := null;
         when others then
           g_lugar := 'Error al recuperar nro_referencia'||'-'|| p_dat_ali_cas.nro_referencia;
           mensaje.cod_respuesta := 1;
           mensaje.nom_respuesta := 'Error';
           mensaje.des_Respuesta := g_lugar;
           p_dat_mensaje         := mensaje;
    end;

    if  v_nro_referencia =  p_dat_ali_cas.nro_referencia then

        if p_dat_ali_cas.tip_edicion='VIN' then
           if p_dat_ali_cas.error is null then
              g_lugar := 'Actualizar ge_spi_ali_cas_tmp';
              begin
                  update  ge_spi_ali_cas_tmp  t
                  set t.est_solicitud='A'
                  where t.nro_referencia= p_dat_ali_cas.nro_referencia;
                  g_lugar := 'Actualizar ge_spi_ali_cas';
                if sql%rowcount > 0 then
                  begin
                    /*buscamos datos de la cuenta a vicular*/
                       begin
                         select c.cta_recordid
                         into v_cta_recordid
                         from ge_spi_cta_cas c
                         where c.nro_cta_solicitante = p_dat_ali_cas.nro_cta_solicitante
                         and c.est_solicitud='A'
                         and c.cta_recordid is not null;
                       exception
                         when no_data_found then
                           v_cta_recordid := null;
                         when others then
                           v_cta_recordid := null;
                       end;
                     /*buscamos el cli_recorid*/
                       begin
                         select c.cli_recordid
                         into v_cli_recordid
                         from ge_spi_cli_cas c
                         where c.est_solicitud ='A'
                         and c.est_cliente     = 'active'
                         and c.cod_persona     = v_cod_persona;
                       exception
                         when no_data_found then
                           v_cli_recordid := null;
                         when others then
                           v_cli_recordid := null;
                       end;

                      update ge_spi_ali_cas t
                      set t.nro_cta_solicitante = p_dat_ali_cas.nro_cta_solicitante,
                      t.cue_recordid = v_cta_recordid,
                      t.cli_recordid = v_cli_recordid
                      where t.cod_persona     = v_cod_persona
                      and t.tip_identificador = v_tip_identificador
                      and t.val_identificador = v_val_identificador;

                    if sql%rowcount > 0 then
                      /**/
                       v_inf_json:='{'||'"nombre":'      ||'"'||FUE_OBT_NOM_PERSONA(v_cod_persona)               ||'"'||','||
                                     '"tip_documento":'  ||'"'||v_tip_identificador                              ||'"'||','||
                                     '"nro_documento":'  ||'"'||v_val_identificador                              ||'"'||','||
                                     '"fec_registro":'   ||'"'||to_char(v_fec_registro, 'DD/MM/YYYY') ||'"'||','||
                                     '"nro_cta":'        ||'"'||p_dat_ali_cas.nro_cta_solicitante                ||'"'||','||
                                     '"est_alias":'      ||'"'||p_dat_ali_cas.est_alias                          ||'"'|| '}';

                       if  p_dat_ali_cas.canal is null then
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                              pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTVAL'),v_inf_json);
                              p_dat_mensaje         := mensaje;
                           elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                             pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTVALPJ'),v_inf_json);
                             p_dat_mensaje         := mensaje;
                           else
                             p_dat_mensaje         := mensaje;
                           end if;

                       elsif p_dat_ali_cas.canal = 'WEBA' then
                         /*se genera la notificacion de alta en un solo paso posterior a la vinculacion*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                             --pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTA1SP'),v_inf_json); --TCE-249 tipo prod 141
                             p_dat_mensaje         := mensaje;
                         elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                             pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTA1SPPJ'),v_inf_json);
                             p_dat_mensaje         := mensaje;
                         end if;

                       elsif p_dat_ali_cas.canal = 'WEBE' then
                          /*se genera la notificacion de edicion en un solo paso posterior a la vinculacion*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                             --pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTED1SP'),v_inf_json);--TCE-249 tipo prod 137
                             p_dat_mensaje         := mensaje;
                          elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                             pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTED1SPPJ'),v_inf_json);
                             p_dat_mensaje         := mensaje;
                          else
                             p_dat_mensaje         := mensaje;
                          end if;
                       end if;
                         /*actualiza ge_spi_cta_cas*/
                         begin
                           g_lugar := 'Actualizar ali_recordid en ge_spi_cta_cas';
                             /*actualiza ge_spi_cta_cas*/
                             update ge_spi_cta_cas ct
                             set  ct.ali_recordid= p_dat_ali_cas.ali_recordID,
                             ct.cli_recordid =  v_cli_recordid
                             where ct.cta_recordid= v_cta_recordid;

                           if sql%rowcount > 0 then
                             p_dat_mensaje         := mensaje;
                           else
                              mensaje.cod_respuesta := 5;
                               mensaje.nom_respuesta := 'Error';
                               mensaje.des_Respuesta := g_lugar;
                               p_dat_mensaje         := mensaje;
                           end if;

                         end;

                        /*cobro de alta/edicion de alias*/
                          if FUG_OBT_PARDINAMICO('CAS_COB_ALTA') = 'S' then
                            --g_car_ali := 'S';
                            if g_car_ali = 'S' then
                               pr_gen_mov_cargo(p_dat_ali_cas.nro_referencia,
                                                rg_cta_cliente,
                                                fug_ini_hora,
                                                v_nro_secuencia);
                            end if;
                          end if;
                    else
                     mensaje.cod_respuesta := 4;
                     mensaje.nom_respuesta := 'Error';
                     mensaje.des_Respuesta := g_lugar;
                     p_dat_mensaje         := mensaje;
                    end if;
                  end;

                else
                  mensaje.cod_respuesta := 3;
                   mensaje.nom_respuesta := 'Error';
                   mensaje.des_Respuesta := g_lugar;
                   p_dat_mensaje         := mensaje;
                end if;
              end;
           ELSE
             /*buscamos la descripcion del error*/
             v_descripcion_error:=fue_obt_des_refcodes('TIP_REC_CAS',p_dat_ali_cas.error) ;

               g_lugar := 'Actualizar error en  ge_spi_cta_cas_tmp';
               begin
                 update GE_SPI_ALI_CAS_TMP c
                 set c.est_solicitud    = 'E',
                     c.error            = p_dat_ali_cas.error||' '||v_descripcion_error
                 where c.nro_referencia = p_dat_ali_cas.nro_referencia;

                 if sql%rowcount > 0 then
                    v_inf_json:='{'||'"nombre":'      ||'"'||FUE_OBT_NOM_PERSONA(v_cod_persona)  ||'"'||','||
                                 '"tip_documento":'   ||'"'||v_tip_identificador                 ||'"'||','||
                                   '"nro_documento":' ||'"'||v_val_identificador                 ||'"'||','||
                                   '"fec_registro":'  ||'"'||to_char(v_fec_registro, 'DD/MM/YYYY')||'"'||','||
                                   '"nro_cta":'       ||'"'||p_dat_ali_cas.nro_cta_solicitante   ||'"'||','||
                                   '"est_alias":'     ||'"'||p_dat_ali_cas.est_alias             ||'"'||','||
                                   '"error":'         ||'"'||v_descripcion_error                ||'}';

                     if  p_dat_ali_cas.canal is null then
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                             pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTVNA'),v_inf_json);
                             p_dat_mensaje         := mensaje;
                           elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                             p_dat_mensaje         := mensaje;
                           else
                             p_dat_mensaje         := mensaje;
                           end if;
                     elsif p_dat_ali_cas.canal = 'WEBA' then
                         /*se genera la notificacion  de error de alta en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                             p_dat_mensaje         := mensaje;
                         elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                              p_dat_mensaje         := mensaje;
                         end if;
                     elsif p_dat_ali_cas.canal = 'WEBE' then
                          /*se genera la notificacion de error edicion en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                              p_dat_mensaje         := mensaje;

                          elsif fu_obt_tip_per(v_cod_persona) = 'J' then

                             p_dat_mensaje         := mensaje;
                          else
                             p_dat_mensaje         := mensaje;
                          end if;
                     end if;

                 Else
                  mensaje.cod_respuesta := 3;
                  mensaje.nom_respuesta := 'Error';
                  mensaje.des_Respuesta := g_lugar;
                  p_dat_mensaje         := mensaje;
                 end if;
               end;
            END IF;
        elsif  p_dat_ali_cas.tip_edicion='DES' then
            if p_dat_ali_cas.error is null then
               g_lugar := 'Actualizar ge_spi_ali_cas_tmp';
              begin

                update  ge_spi_ali_cas_tmp  t
                set t.est_solicitud='A'
                where t.nro_referencia= p_dat_ali_cas.nro_referencia;
                 g_lugar := 'Actualizar ge_spi_ali_cas';
               if sql%rowcount > 0 then
                  begin
                      update ge_spi_ali_cas t
                      set t.nro_cta_solicitante = null,
                      t.cue_recordid = null
                      where t.cod_persona     = v_cod_persona
                      and t.tip_identificador = v_tip_identificador
                      and t.val_identificador     = v_val_identificador;
                     if sql%rowcount > 0 then
                       v_inf_json:='{'||'"nombre":'      ||'"'||FUE_OBT_NOM_PERSONA(v_cod_persona) ||'"'||','||
                                 '"tip_documento":'    ||'"'||v_tip_identificador                ||'"'||','||
                                 '"nro_documento":'           ||'"'||v_val_identificador                ||'"'||','||
                                 '"fec_registro":'            ||'"'||to_char(v_fec_registro, 'DD/MM/YYYY')                     ||'"'||','||
                                 '"nro_cta":'                 ||'"'||p_dat_ali_cas.nro_cta_solicitante  ||'"'||','||
                                 '"est_alias":'               ||'"'||v_estado_alias                     ||'"' || '}';
                       if  p_dat_ali_cas.canal is null then
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                              pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTDAL'),v_inf_json);
                              p_dat_mensaje         := mensaje;
                           elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                              p_dat_mensaje         := mensaje;
                           else
                             p_dat_mensaje         := mensaje;
                           end if;
                       elsif p_dat_ali_cas.canal = 'WEBA' then
                         /*se genera la notificacion de alta en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                              p_dat_mensaje         := mensaje;
                         elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                             p_dat_mensaje         := mensaje;
                         end if;
                       elsif p_dat_ali_cas.canal = 'WEBE' then
                          /*se genera la notificacion de edicion en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                              p_dat_mensaje         := mensaje;

                          elsif fu_obt_tip_per(v_cod_persona) = 'J' then

                             p_dat_mensaje         := mensaje;
                          end if;
                       end if;
                           /*se actualiza la tabla ge_spi_cta_Cas para desvincular
                             el alias*/
                           begin
                             g_lugar := 'Desvincular alias en ge_spi_cta_cas';

                             update ge_spi_cta_Cas  cta
                             set cta.ali_recordid = null
                             where cta.cta_recordid = p_dat_ali_cas.cue_recordID;

                             if sql%rowcount > 0 then
                               p_dat_mensaje         := mensaje;
                             else
                                mensaje.cod_respuesta := 5;
                                mensaje.nom_respuesta := 'Error';
                                mensaje.des_Respuesta := g_lugar;
                                p_dat_mensaje         := mensaje;
                             end if;

                           end;
                     /*cobro de alta/edicion de alias*/
                          if FUG_OBT_PARDINAMICO('CAS_COB_ALTA') = 'S' then
                            --g_car_ali := 'S';
                            if g_car_ali = 'S'  then
                               pr_gen_mov_cargo(p_dat_ali_cas.nro_referencia,
                                                rg_cta_cliente,
                                                fug_ini_hora,
                                                v_nro_secuencia);
                            end if;
                          end if;
                     else
                      mensaje.cod_respuesta := 4;
                      mensaje.nom_respuesta := 'Error';
                      mensaje.des_Respuesta := g_lugar;
                      p_dat_mensaje         := mensaje;
                     end if;
                   end;
               else
                  mensaje.cod_respuesta := 3;
                   mensaje.nom_respuesta := 'Error';
                   mensaje.des_Respuesta := g_lugar;
                   p_dat_mensaje         := mensaje;
              end if;
              end;

           ELSE
             /*buscamos la descripcion del error*/
             v_descripcion_error:=fue_obt_des_refcodes('TIP_REC_CAS',p_dat_ali_cas.error) ;
               g_lugar := 'Actualizar error en  ge_spi_cta_cas_tmp';
               begin
                 update ge_spi_ali_cas_tmp c
                 set c.est_solicitud    = 'E',
                     c.error            = p_dat_ali_cas.error||' '||v_descripcion_error
                 where c.nro_referencia = p_dat_ali_cas.nro_referencia;
                if sql%rowcount > 0 then
                   v_inf_json:='{'||'"nombre":'      ||'"'||FUE_OBT_NOM_PERSONA(v_cod_persona)               ||'"'||','||
                                 '"tip_documento":'    ||'"'||v_tip_identificador                ||'"'||','||
                                 '"nro_documento":'           ||'"'||v_val_identificador                ||'"'||','||
                                 '"fec_registro":'            ||'"'||to_char(v_fec_registro, 'DD/MM/YYYY')                     ||'"'||','||
                                 '"nro_cta":'                 ||'"'||p_dat_ali_cas.nro_cta_solicitante  ||'"'||','||
                                 '"est_alias":'               ||'"'||v_estado_alias                     ||'"'||','||
                                 '"error":'                  ||'"'||v_descripcion_error                 ||'"' || '}';

                    if  p_dat_ali_cas.canal is null then
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                               pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTDNA'),v_inf_json);
                               p_dat_mensaje         := mensaje;
                           elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                              p_dat_mensaje         := mensaje;
                           else
                             p_dat_mensaje         := mensaje;
                           end if;
                       elsif p_dat_ali_cas.canal = 'WEBA' then
                         /*se genera la notificacion de alta en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                             p_dat_mensaje         := mensaje;
                         elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                             p_dat_mensaje         := mensaje;
                         else
                            p_dat_mensaje         := mensaje;
                         end if;
                       elsif p_dat_ali_cas.canal = 'WEBE' then
                          /*se genera la notificacion de edicion en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                              p_dat_mensaje         := mensaje;
                          elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                             p_dat_mensaje         := mensaje;
                          else
                             p_dat_mensaje         := mensaje;
                          end if;
                       end if;

               else
                  mensaje.cod_respuesta := 5;
                  mensaje.nom_respuesta := 'Error';
                  mensaje.des_Respuesta := g_lugar;
                  p_dat_mensaje         := mensaje;
               end if;
             end;
           END IF;
        elsif  p_dat_ali_cas.tip_edicion='UPD' then
           IF p_dat_ali_cas.error is null then
              g_lugar := 'Actualizar ge_spi_ali_cas_tmp';
               begin
                  update  ge_spi_ali_cas_tmp  t
                  set t.est_solicitud='A'
                  where t.nro_referencia= p_dat_ali_cas.nro_referencia;
                   g_lugar := 'Actualizar ge_spi_ali_cas';
                 if sql%rowcount > 0 then
                   begin
                    update ge_spi_ali_cas t
                      set t.fec_ven_registro  = p_dat_ali_cas.fec_ven_registro
                      where t.cod_persona     = v_cod_persona
                      and t.tip_identificador = v_tip_identificador
                      and t.val_identificador  = v_val_identificador;
                     if sql%rowcount > 0 then
                       v_inf_json:='{'||'"nombre":'      ||'"'||FUE_OBT_NOM_PERSONA(v_cod_persona)               ||'"'||','||
                                   '"tip_documento":'  ||'"'||v_tip_identificador                ||'"'||','||
                                   '"nro_documento":'       ||'"'||v_val_identificador                ||'"'||','||
                                   '"fec_ven_registro":'    ||'"'||to_char(p_dat_ali_cas.fec_ven_registro, 'DD/MM/YYYY')     ||'"'||','||
                                   '"nro_cta":'             ||'"'||p_dat_ali_cas.nro_cta_solicitante  ||'"'||','||
                                   '"est_alias":'           ||'"'||p_dat_ali_cas.est_alias            ||'"'|| '}';
                       if  p_dat_ali_cas.canal is null then
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                               pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTAAL'),v_inf_json);
                               p_dat_mensaje         := mensaje;
                           elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                              p_dat_mensaje         := mensaje;
                           else
                             p_dat_mensaje         := mensaje;
                           end if;
                       elsif p_dat_ali_cas.canal = 'WEBA' then
                         /*se genera la notificacion de alta en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                           p_dat_mensaje         := mensaje;
                         elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                            p_dat_mensaje         := mensaje;
                         else
                           p_dat_mensaje         := mensaje;
                         end if;
                       elsif p_dat_ali_cas.canal = 'WEBE' then
                          /*se genera la notificacion de edicion en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                              p_dat_mensaje         := mensaje;

                          elsif fu_obt_tip_per(v_cod_persona) = 'J' then

                             p_dat_mensaje         := mensaje;
                          else
                             p_dat_mensaje         := mensaje;
                          end if;
                       end if;
                       /*cobro de alta/edicion de alias*/
                          if FUG_OBT_PARDINAMICO('CAS_COB_ALTA') = 'S' then
                            --g_car_ali := 'S';
                            if g_car_ali  ='S' then
                               pr_gen_mov_cargo(p_dat_ali_cas.nro_referencia,
                                                rg_cta_cliente,
                                                fug_ini_hora,
                                                v_nro_secuencia);
                            end if;
                          end if;
                    Else
                     mensaje.cod_respuesta := 4;
                     mensaje.nom_respuesta := 'Error';
                     mensaje.des_Respuesta := g_lugar;
                     p_dat_mensaje         := mensaje;
                    end if;
                   end;
                 else
                   mensaje.cod_respuesta := 3;
                     mensaje.nom_respuesta := 'Error';
                     mensaje.des_Respuesta := g_lugar;
                     p_dat_mensaje         := mensaje;
                 end if;
               end;
           ELSE
             /*buscamos la descripcion del error*/
             v_descripcion_error:=fue_obt_des_refcodes('TIP_REC_CAS',p_dat_ali_cas.error) ;
             g_lugar := 'Actualizar error en  ge_spi_cta_cas_tmp';
             begin
               update ge_spi_ali_cas_tmp c
               set c.est_solicitud    = 'E',
                   c.error            = p_dat_ali_cas.error||' '||v_descripcion_error
               where c.nro_referencia = p_dat_ali_cas.nro_referencia;
               if sql%rowcount > 0 then
                 v_inf_json:='{'||'"nombre":'      ||'"'||FUE_OBT_NOM_PERSONA(v_cod_persona)               ||'"'||','||
                                  '"tip_documento":'  ||'"'||v_tip_identificador                      ||'"'||','||
                                   '"nro_documento":'       ||'"'||v_val_identificador                ||'"'||','||
                                   '"fec_ven_registro":'    ||'"'||to_char(p_dat_ali_cas.fec_ven_registro, 'DD/MM/YYYY')     ||'"'||','||
                                   '"nro_cta":'             ||'"'||p_dat_ali_cas.nro_cta_solicitante  ||'"'||','||
                                   '"est_alias":'           ||'"'||p_dat_ali_cas.est_alias            ||'"'||','||
                                   '"error":'                ||'"'||v_descripcion_error               ||'"' || '}';
                      if  p_dat_ali_cas.canal is null then
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                               pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTNAAL'),v_inf_json);
                               p_dat_mensaje         := mensaje;
                           elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                              p_dat_mensaje         := mensaje;
                           else
                             p_dat_mensaje         := mensaje;
                           end if;
                       elsif p_dat_ali_cas.canal = 'WEBA' then
                         /*se genera la notificacion de alta en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                             p_dat_mensaje         := mensaje;
                         elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                            p_dat_mensaje         := mensaje;
                         else
                           p_dat_mensaje         := mensaje;
                         end if;
                       elsif p_dat_ali_cas.canal = 'WEBE' then
                          /*se genera la notificacion de edicion en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                              p_dat_mensaje         := mensaje;

                          elsif fu_obt_tip_per(v_cod_persona) = 'J' then

                             p_dat_mensaje         := mensaje;
                          else
                             p_dat_mensaje         := mensaje;
                          end if;
                       end if;
              Else
                  mensaje.cod_respuesta := 5;
                  mensaje.nom_respuesta := 'Error';
                  mensaje.des_Respuesta := g_lugar;
                  p_dat_mensaje         := mensaje;
              end if;
              end;

         END IF;
        elsif  p_dat_ali_cas.tip_edicion='ACT' then
           if p_dat_ali_cas.error is null then
                g_lugar := 'Actualizar ge_spi_ali_cas_tmp';
              begin
                  update  ge_spi_ali_cas_tmp  t
                  set t.est_solicitud='A'
                  where t.nro_referencia= p_dat_ali_cas.nro_referencia;
                  g_lugar := 'Actualizar ge_spi_ali_cas';
                if sql%rowcount > 0 then
                   begin

                      update ge_spi_ali_cas t
                      set t.est_alias  = v_estado_alias
                      where t.cod_persona     = v_cod_persona
                      and t.tip_identificador = v_tip_identificador
                      and t.val_identificador  = v_val_identificador;
                      if sql%rowcount > 0 then
                        v_inf_json:='{'||'"nombre":'      ||'"'||FUE_OBT_NOM_PERSONA(v_cod_persona)   ||'"'||','||
                                      '"tip_documento":'    ||'"'||v_tip_identificador                ||'"'||','||
                                     '"nro_documento":'        ||'"'||v_val_identificador                ||'"'||','||
                                     '"fec_registro":'        ||'"'||to_char(v_fec_registro, 'DD/MM/YYYY')                     ||'"'||','||
                                     '"nro_cta":'             ||'"'||p_dat_ali_cas.nro_cta_solicitante  ||'"'||','||
                                     '"est_alias":'           ||'"'||v_estado_alias                     ||'"' || '}';

                       if  p_dat_ali_cas.canal is null then
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                               pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTACA'),v_inf_json);
                               p_dat_mensaje         := mensaje;
                           elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                              p_dat_mensaje         := mensaje;
                           else
                             p_dat_mensaje         := mensaje;
                           end if;
                       elsif p_dat_ali_cas.canal = 'WEBA' then
                         /*se genera la notificacion de alta en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                            p_dat_mensaje         := mensaje;
                         elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                            p_dat_mensaje         := mensaje;
                         else
                           p_dat_mensaje         := mensaje;
                         end if;
                       elsif p_dat_ali_cas.canal = 'WEBE' then
                          /*se genera la notificacion de edicion en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                              p_dat_mensaje         := mensaje;

                          elsif fu_obt_tip_per(v_cod_persona) = 'J' then

                             p_dat_mensaje         := mensaje;
                          else
                             p_dat_mensaje         := mensaje;
                          end if;
                       end if;
                       /*cobro de alta/edicion de alias*/
                          if FUG_OBT_PARDINAMICO('CAS_COB_ALTA') = 'S' then
                            --g_car_ali := 'S';
                            if g_car_ali  ='S' then
                               pr_gen_mov_cargo(p_dat_ali_cas.nro_referencia,
                                                rg_cta_cliente,
                                                fug_ini_hora,
                                                v_nro_secuencia);
                            end if;
                          end if;
                      else
                       mensaje.cod_respuesta := 4;
                       mensaje.nom_respuesta := 'Error';
                       mensaje.des_Respuesta := g_lugar;
                       p_dat_mensaje         := mensaje;
                      end if;
                   end;
                else
                  mensaje.cod_respuesta := 3;
                     mensaje.nom_respuesta := 'Error';
                     mensaje.des_Respuesta := g_lugar;
                     p_dat_mensaje         := mensaje;
                end if;
              end;
           ELSE
             /*buscamos la descripcion del error*/
             v_descripcion_error:=fue_obt_des_refcodes('TIP_REC_CAS',p_dat_ali_cas.error) ;
             g_lugar := 'Actualizar error en  ge_spi_cta_cas_tmp';
              begin
               update ge_spi_ali_cas_tmp c
               set c.est_solicitud    = 'E',
                   c.error            = p_dat_ali_cas.error||' '||v_descripcion_error
               where c.nro_referencia = p_dat_ali_cas.nro_referencia;
               if sql%rowcount > 0 then
                  v_inf_json:='{'||'"nombre":'      ||'"'||FUE_OBT_NOM_PERSONA(v_cod_persona)  ||'"'||','||
                                   '"tip_documento":'    ||'"'||v_tip_identificador                ||'"'||','||
                                   '"nro_documento":'    ||'"'||v_val_identificador                ||'"'||','||
                                   '"fec_ven_registro":' ||'"'||to_char(p_dat_ali_cas.fec_ven_registro, 'DD/MM/YYYY')     ||'"'||','||
                                   '"nro_cta":'          ||'"'||p_dat_ali_cas.nro_cta_solicitante  ||'"'||','||
                                   '"est_alias":'        ||'"'||p_dat_ali_cas.est_alias            ||'"'||','||
                                   '"error":'            ||'"'||v_descripcion_error                ||'"'|| '}';
                    if  p_dat_ali_cas.canal is null then
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                               pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTANA'),v_inf_json);
                               p_dat_mensaje         := mensaje;
                           elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                              p_dat_mensaje         := mensaje;
                           else
                             p_dat_mensaje         := mensaje;
                           end if;
                    elsif p_dat_ali_cas.canal = 'WEBA' then
                         /*se genera la notificacion de alta en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                             p_dat_mensaje         := mensaje;
                         elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                             p_dat_mensaje         := mensaje;
                         else
                           p_dat_mensaje         := mensaje;
                         end if;
                    elsif p_dat_ali_cas.canal = 'WEBE' then
                          /*se genera la notificacion de edicion en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                              p_dat_mensaje         := mensaje;

                          elsif fu_obt_tip_per(v_cod_persona) = 'J' then

                             p_dat_mensaje         := mensaje;
                          else
                             p_dat_mensaje         := mensaje;
                          end if;
                   end if;

               Else
                  mensaje.cod_respuesta := 5;
                  mensaje.nom_respuesta := 'Error';
                  mensaje.des_Respuesta := g_lugar;
                  p_dat_mensaje         := mensaje;
               end if;
              end;
           END IF;
        elsif  p_dat_ali_cas.tip_edicion='SUS' then
           if p_dat_ali_cas.error is null then
             g_lugar := 'Actualizar ge_spi_ali_cas_tmp';
             begin
               update  ge_spi_ali_cas_tmp  t
               set t.est_solicitud='A'
               where t.nro_referencia= p_dat_ali_cas.nro_referencia;
               g_lugar := 'Actualizar ge_spi_ali_cas';
              if sql%rowcount > 0 then
                 begin
                   update ge_spi_ali_cas t
                    set t.est_alias  = v_estado_alias
                    where t.cod_persona     = v_cod_persona
                    and t.tip_identificador = v_tip_identificador
                    and t.val_identificador  = v_val_identificador;
                   if sql%rowcount > 0 then
                      v_inf_json:='{'||'"nombre":'      ||'"'||FUE_OBT_NOM_PERSONA(v_cod_persona)               ||'"'||','||
                                     '"tip_documento":'    ||'"'||v_tip_identificador                 ||'"'||','||
                                     '"nro_documento":'      ||'"'||v_val_identificador                 ||'"'||','||
                                     '"fec_registro":'        ||'"'||to_char(v_fec_registro, 'DD/MM/YYYY')                     ||'"'||','||
                                     '"nro_cta":'             ||'"'||p_dat_ali_cas.nro_cta_solicitante  ||'"'||','||
                                     '"est_alias":'           ||'"'||v_estado_alias                     ||'"' || '}';
                       if  p_dat_ali_cas.canal is null then
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                               pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTSAL'),v_inf_json);
                               p_dat_mensaje         := mensaje;
                           elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                              p_dat_mensaje         := mensaje;
                           else
                             p_dat_mensaje         := mensaje;
                           end if;
                       elsif p_dat_ali_cas.canal = 'WEBA' then
                         /*se genera la notificacion de alta en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                             p_dat_mensaje         := mensaje;
                         elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                            p_dat_mensaje         := mensaje;
                         else
                            p_dat_mensaje         := mensaje;
                         end if;
                       elsif p_dat_ali_cas.canal = 'WEBE' then
                          /*se genera la notificacion de edicion en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                              p_dat_mensaje         := mensaje;

                          elsif fu_obt_tip_per(v_cod_persona) = 'J' then

                             p_dat_mensaje         := mensaje;
                          else
                             p_dat_mensaje         := mensaje;
                          end if;
                       end if;
                       /*cobro de alta/edicion de alias*/
                          if FUG_OBT_PARDINAMICO('CAS_COB_ALTA') = 'S' then
                            --g_car_ali := 'S';
                            if g_car_ali  ='S' then
                               pr_gen_mov_cargo(p_dat_ali_cas.nro_referencia,
                                                rg_cta_cliente,
                                                fug_ini_hora,
                                                v_nro_secuencia);
                            end if;
                          end if;
                  else
                   mensaje.cod_respuesta := 4;
                     mensaje.nom_respuesta := 'Error';
                     mensaje.des_Respuesta := g_lugar;
                     p_dat_mensaje         := mensaje;
                 end if;
                end;
              else
               mensaje.cod_respuesta := 3;
               mensaje.nom_respuesta := 'Error';
               mensaje.des_Respuesta := g_lugar;
               p_dat_mensaje         := mensaje;
              end if;
             end;
          ELSE
             /*buscamos la descripcion del error*/
             v_descripcion_error:=fue_obt_des_refcodes('TIP_REC_CAS',p_dat_ali_cas.error) ;
             g_lugar := 'Actualizar error en  ge_spi_cta_cas_tmp';
             begin
                 update ge_spi_ali_cas_tmp c
                 set c.est_solicitud    = 'E',
                     c.error            = p_dat_ali_cas.error||' '||v_descripcion_error
                 where c.nro_referencia = p_dat_ali_cas.nro_referencia;
                if sql%rowcount > 0 then
                   v_inf_json:='{'||'"nombre":'      ||'"'||FUE_OBT_NOM_PERSONA(v_cod_persona)     ||'"'||','||
                                    '"tip_documento":'    ||'"'||v_tip_identificador                ||'"'||','||
                                     '"nro_documento":'   ||'"'||v_val_identificador                ||'"'||','||
                                     '"fec_registro":'    ||'"'||to_char(v_fec_registro, 'DD/MM/YYYY')                     ||'"'||','||
                                     '"nro_cta":'         ||'"'||p_dat_ali_cas.nro_cta_solicitante  ||'"'||','||
                                     '"est_alias":'       ||'"'||v_estado_alias                     ||'"'||','||
                                     '"error":'           ||'"'||v_descripcion_error                ||'"' || '}';

                      if  p_dat_ali_cas.canal is null then
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                               pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTNSAL'),v_inf_json);
                               p_dat_mensaje         := mensaje;
                           elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                              p_dat_mensaje         := mensaje;
                           else
                             p_dat_mensaje         := mensaje;
                           end if;
                       elsif p_dat_ali_cas.canal = 'WEBA' then
                         /*se genera la notificacion de alta en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                            p_dat_mensaje         := mensaje;
                         elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                            p_dat_mensaje         := mensaje;
                         else
                           p_dat_mensaje         := mensaje;
                         end if;
                       elsif p_dat_ali_cas.canal = 'WEBE' then
                          /*se genera la notificacion de edicion en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                              p_dat_mensaje         := mensaje;

                          elsif fu_obt_tip_per(v_cod_persona) = 'J' then

                             p_dat_mensaje         := mensaje;
                          else
                             p_dat_mensaje         := mensaje;
                          end if;
                       end if;
                else
                  mensaje.cod_respuesta := 5;
                  mensaje.nom_respuesta := 'Error';
                  mensaje.des_Respuesta := g_lugar;
                  p_dat_mensaje         := mensaje;
                end if;
              end;
         END IF;

        elsif  p_dat_ali_cas.tip_edicion='ELI' then
           IF p_dat_ali_cas.error is null then
             g_lugar := 'Actualizar ge_spi_ali_cas_tmp';
             begin
               update  ge_spi_ali_cas_tmp  t
                set t.est_solicitud='A',
                t.est_alias = p_dat_ali_cas.est_alias
                where t.nro_referencia= p_dat_ali_cas.nro_referencia;

               g_lugar := 'Eliminar registro ge_spi_ali_cas';
                if sql%rowcount > 0 then
                 begin
                  delete ge_spi_ali_cas t
                  where t.cod_persona     = v_cod_persona
                  and t.tip_identificador = v_tip_identificador
                  and t.val_identificador  = v_val_identificador;
                   if sql%rowcount > 0 then
                      v_inf_json:='{'||'"nombre":'      ||'"'||FUE_OBT_NOM_PERSONA(v_cod_persona)      ||'"'||','||
                                       '"tip_documento":'    ||'"'||v_tip_identificador                ||'"'||','||
                                       '"nro_documento":'    ||'"'||v_val_identificador                ||'"'||','||
                                       '"fec_registro":'     ||'"'||to_char(v_fec_registro, 'DD/MM/YYYY') ||'"'||','||
                                       '"nro_cta":'          ||'"'||p_dat_ali_cas.nro_cta_solicitante  ||'"'||','||
                                       '"est_alias":'        ||'"'||'Eliminado'                        ||'"'|| '}';
                        if  p_dat_ali_cas.canal is null then
                           if fu_obt_tip_per(v_cod_persona) = 'F' then
                               pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTEAL'),v_inf_json);
                               p_dat_mensaje         := mensaje;
                           elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                              p_dat_mensaje         := mensaje;
                           else
                             p_dat_mensaje         := mensaje;
                           end if;
                       elsif p_dat_ali_cas.canal = 'WEBA' then
                         /*se genera la notificacion de alta en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                             p_dat_mensaje         := mensaje;
                         elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                            p_dat_mensaje         := mensaje;
                         else
                            p_dat_mensaje         := mensaje;
                         end if;
                       elsif p_dat_ali_cas.canal = 'WEBE' then
                          /*se genera la notificacion de edicion en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                              p_dat_mensaje         := mensaje;
                          elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                             p_dat_mensaje         := mensaje;
                          else
                             p_dat_mensaje         := mensaje;
                          end if;
                       end if;
                       /*cobro de alta/edicion de alias*/
                          if FUG_OBT_PARDINAMICO('CAS_COB_ALTA') = 'S' then
                            --g_car_ali := 'S';
                            if g_car_ali  ='S' then
                               pr_gen_mov_cargo(p_dat_ali_cas.nro_referencia,
                                                rg_cta_cliente,
                                                fug_ini_hora,
                                                v_nro_secuencia);
                            end if;
                          end if;
                   else
                     mensaje.cod_respuesta := 4;
                     mensaje.nom_respuesta := 'Error';
                     mensaje.des_Respuesta := g_lugar;
                     p_dat_mensaje         := mensaje;
                   end if;
                 end;
               else
                     mensaje.cod_respuesta := 3;
                     mensaje.nom_respuesta := 'Error';
                     mensaje.des_Respuesta := g_lugar;
                     p_dat_mensaje         := mensaje;
               end if;
             end;
           ELSE
             /*buscamos la descripcion del error*/
             v_descripcion_error:=fue_obt_des_refcodes('TIP_REC_CAS',p_dat_ali_cas.error) ;
             g_lugar := 'Actualizar error en  ge_spi_cta_cas_tmp';
             begin
               update ge_spi_ali_cas_tmp c
               set c.est_solicitud    = 'E',
                   c.error            = p_dat_ali_cas.error||' '||v_descripcion_error
               where c.nro_referencia = p_dat_ali_cas.nro_referencia;
              if sql%rowcount > 0 then
                 v_inf_json:='{'||'"nombre":'      ||'"'||FUE_OBT_NOM_PERSONA(v_cod_persona)               ||'"'||','||'"tip_documento":'     ||'"'||v_tip_identificador                ||'"'||','||
                                   '"nro_documento":'    ||'"'||v_val_identificador                ||'"'||','||
                                   '"fec_ven_registro":' ||'"'||p_dat_ali_cas.fec_ven_registro     ||'"'||','||
                                   '"nro_cta":'          ||'"'||p_dat_ali_cas.nro_cta_solicitante  ||'"'||','||
                                   '"est_alias":'        ||'"'||v_estado_alias                     ||'"'||','||
                                   '"error":'            ||'"'||v_descripcion_error                ||'"' || '}';
                      if  p_dat_ali_cas.canal is null then
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                               pas_spi.pr_env_alerta(v_cod_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTNCAL'),v_inf_json);
                               p_dat_mensaje         := mensaje;
                           elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                              p_dat_mensaje         := mensaje;
                           else
                             p_dat_mensaje         := mensaje;
                           end if;
                       elsif p_dat_ali_cas.canal = 'WEBA' then
                         /*se genera la notificacion de alta en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                             p_dat_mensaje         := mensaje;
                         elsif fu_obt_tip_per(v_cod_persona) = 'J' then
                             p_dat_mensaje         := mensaje;
                         else
                           p_dat_mensaje         := mensaje;
                         end if;
                       elsif p_dat_ali_cas.canal = 'WEBE' then
                          /*se genera la notificacion de edicion en un solo paso*/
                         if fu_obt_tip_per(v_cod_persona) = 'F' then
                              p_dat_mensaje         := mensaje;

                          elsif fu_obt_tip_per(v_cod_persona) = 'J' then

                             p_dat_mensaje         := mensaje;
                          else
                             p_dat_mensaje         := mensaje;
                          end if;
                       end if;
              else
                mensaje.cod_respuesta := 3;
                  mensaje.nom_respuesta := 'Error';
                  mensaje.des_Respuesta := g_lugar;
                  p_dat_mensaje         := mensaje;
              end if;
             end;
           END IF;
        end if;
    else
       g_lugar := 'Referencia recibida distinta enviada' ||
      '- Recibida: '|| p_dat_ali_cas.nro_referencia||
      '- Buscada: '||v_nro_referencia;

      mensaje.cod_respuesta := 2;
      mensaje.nom_respuesta := 'Error';
      mensaje.des_Respuesta := g_lugar;
      p_dat_mensaje         := mensaje;

    end if;
 exception
   when ex_salir then
    pas_cas.g_cod_error := 20;
    pas_cas.g_msj_error := 'No se puede generar la solicitud. Saldo insuficiente';
   when others then
     mensaje.cod_respuesta := 1;
      mensaje.nom_respuesta := 'Error';
      mensaje.des_Respuesta := 'Ocurrio un error al procesar la respuesta. '||sqlerrm;
      p_dat_mensaje         := mensaje;
  end pr_pro_msj_rec_edi_ali;
end PAS_CAS;
/

