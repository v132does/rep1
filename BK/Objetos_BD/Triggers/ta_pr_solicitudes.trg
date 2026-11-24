CREATE OR REPLACE TRIGGER IT.TA_PR_SOLICITUDES
 AFTER DELETE OR INSERT OR UPDATE
 ON "IT"."PR_SOLICITUDES"
 FOR EACH ROW

DECLARE
   v_nro_solicitud ge_solicitudes.nro_solicitud%type;
   r_gsges ge_sol_gestiones%rowtype;
   v_cod_mon_linea ba_monedas.cod_moneda%type;
   v_cot_mon_ori   ge_cotizaciones.val_conversion%type;
   v_cot_mon_des   ge_cotizaciones.val_conversion%type;

    v_cod_error number := 0;

/* Inserta las gestiones de la solicitud. */
PROCEDURE LP_INS_PR_SOL_GES
 (RP_RSGES IN PR_SOL_GESTIONES%ROWTYPE
 );
   r_psges pr_sol_gestiones%rowtype;

/* Inserta las gestiones de la solicitud. */
PROCEDURE LP_INS_PR_SOL_GES
 (RP_RSGES IN PR_SOL_GESTIONES%ROWTYPE
 )
 IS
BEGIN
   insert into pr_sol_gestiones
     (nro_solicitud, estado, fecha,
      cod_usuario, observacion)
   values
     (rp_rsges.nro_solicitud, rp_rsges.estado, rp_rsges.fecha,
      rp_rsges.cod_usuario, rp_rsges.observacion);
END;
--2659 Verifica Evaluacion de Riesgos
FUNCTION fp_ver_dat_rie_evaluaciones(p_nro_solicitud NUMBER) RETURN BOOLEAN IS
    v_existe VARCHAR2(1) := 'N';
BEGIN
    SELECT 'S' INTO v_existe FROM ge_dat_rie_evaluaciones WHERE nro_solicitud = p_nro_solicitud;
    IF v_existe = 'N' THEN
         RETURN FALSE;
    ELSE
         RETURN TRUE;
    END IF;
EXCEPTION
    WHEN no_data_found THEN
         RETURN FALSE;
    WHEN too_many_rows THEN
         RETURN TRUE;
    WHEN OTHERS THEN
         raise_application_error(-20000, 'Error al consultar (fp_ver_dat_rie_evaluaciones). ' || SQLERRM);
END;
/* Actualiza estado del informe de crédito. */
PROCEDURE LP_ACT_GE_INF_CREDITOS(P_ESTADO IN VARCHAR2)
 IS
BEGIN
   update ge_inf_creditos
   set estado = P_ESTADO
   where nro_solicitud = :new.nro_solicitud;
   exception
      when no_data_found then
         null;
      when others then
         raise_application_error(-20000,'Act. Informe Crédito. '||sqlerrm);
END;


/*Actualiza Perfil del Cliente para Pre Aprobados*/
PROCEDURE LP_ACT_PER_CLIENTE IS

   v_existe           varchar2(1) := 'N';
   v_fec_apertura     pr_cta_prestamos.fec_inicio%type := pag_cal.FU_OBT_FEC_ACTUAL(6);
   v_can_tra_debito   number := nvl(to_number(fug_obt_pardinamico('CAN_TRA_DEBITO')),0);
   v_can_tra_credito  number := nvl(to_number(fug_obt_pardinamico('CAN_TRA_CREDITO')),0);
   v_por_pro_debito   number := nvl(to_number(fug_obt_pardinamico('POR_PRO_DEBITO')),0);
   v_por_pro_credito  number := nvl(to_number(fug_obt_pardinamico('POR_PRO_CREDITO')),0);
   v_cod_persona      cr_inf_fondos.cod_persona%type;
   v_monto            number := 0;


   BEGIN

       v_cod_persona  := :new.cod_persona;
       --Informacion adicional acerca de los Fondos de la Persona.
       BEGIN
          UPDATE cr_inf_fondos
             SET fon_prestamos = 'S',
                 pro_gas_operativos = 'S'
           WHERE cod_persona = v_cod_persona;
          IF sql%notfound THEN
             INSERT INTO cr_inf_fondos (cod_persona, fon_prestamos, pro_gas_operativos)
             VALUES (v_cod_persona, 'S', 'S');
          END IF;
       EXCEPTION
           WHEN OTHERS THEN
             raise_application_error(-20004, 'Error al insertar datos en CR_INF_FONDOS. Persona: '
             ||v_cod_persona||SQLERRM);
       END;

        --Actividades esperadas de Clientes.
       v_monto :=  (((:new.monto*v_por_pro_credito)/100)+:new.monto);
       
       BEGIN
          SELECT 'S'
            INTO v_existe
            FROM cr_act_esperadas
           WHERE cod_persona = v_cod_persona
             AND cod_moneda = :new.cod_moneda
             and (mto_pro_debito > v_monto or mto_pro_credito > v_monto);
       EXCEPTION
          WHEN others THEN
             v_existe := 'N';
       END;
       IF v_existe = 'N' THEN 
           BEGIN
              UPDATE cr_act_esperadas
                 SET can_tra_debito = v_can_tra_debito,
                     can_tra_credito = v_can_tra_credito,
                     mto_pro_debito = v_monto,
                     mto_pro_credito = v_monto
               WHERE cod_persona = v_cod_persona
                AND  fecha = v_fec_apertura
                and  cod_moneda = :new.cod_moneda;
              IF sql%notfound THEN
                 INSERT INTO cr_act_esperadas (cod_persona, cod_moneda, fecha, can_tra_debito,
                                               can_tra_credito, mto_pro_debito, mto_pro_credito)
                 VALUES (v_cod_persona, :new.cod_moneda, v_fec_apertura, v_can_tra_debito,
                        v_can_tra_credito, v_monto, v_monto);
              END IF;
           EXCEPTION
                WHEN OTHERS THEN
                  raise_application_error(-20004, 'Error al insertar datos en CR_INF_FONDOS. Persona: '
                  ||v_cod_persona||SQLERRM);
           END;
       END IF;

       --Tipos de Operaciones de la Persona.
       BEGIN
          SELECT 'S'
            INTO v_existe
            FROM cr_per_tip_operaciones
           WHERE cod_persona = v_cod_persona
             AND cod_modulo = 3
             AND cod_modalidad = 31;
       EXCEPTION
          WHEN others THEN
             v_existe := 'N';
       END;
       IF v_existe = 'N' THEN
          BEGIN
             INSERT INTO cr_per_tip_operaciones  (cod_persona, cod_modulo, cod_modalidad)
             VALUES (v_cod_persona, '3', '31');
          EXCEPTION
             WHEN OTHERS THEN
                  raise_application_error(-20004, 'Error al insertar datos en CR_PER_TIP_OPERACIONES. Persona: '
                  ||v_cod_persona||SQLERRM);
          END;
       END IF;
END;


BEGIN
   if updating and :new.estado <> :old.estado Then
      if :new.estado in ('N') then
          --- Actualizar a nulo las cuentas que posean dicha solicitud
           update pr_cta_prestamos
            set nro_sol_renovada = null
           where nro_sol_renovada = :new.nro_solicitud;
      end if;
      If :new.estado = 'L' then
         --- Actualizar solicitudes a pendiente de liquidación
         BEGIN
            select nro_solicitud into v_nro_solicitud
              from ge_solicitudes
             where nro_sol_prestamo = :new.nro_solicitud;
            update ge_solicitudes
               set cod_estado = 'PLI'
             where nro_solicitud = v_nro_solicitud;

         -- Inserta la Gestión
         r_gsges.cod_usuario := user;
         r_gsges.nro_solicitud := v_nro_solicitud;
         r_gsges.cod_estado    := 'PLI';
         prg_ins_ge_sol_gesti(r_gsges);
         --
         exception
            when no_data_found then
               null;
            when others then
               raise_application_error(-20000,
               'Act. Solicitud '||sqlerrm);
         END;
      Elsif :new.estado = 'A' Then
         --- Actualizar solicitudes a Desembolsado
         BEGIN
            select nro_solicitud into v_nro_solicitud
              from ge_solicitudes
             where nro_sol_prestamo = :new.nro_solicitud;
            update ge_solicitudes
               set cod_estado = 'DES'
             where nro_solicitud = v_nro_solicitud;

         -- Inserta la Gestión
         r_gsges.cod_usuario := user;
         r_gsges.nro_solicitud := v_nro_solicitud;
         r_gsges.cod_estado    := 'DES';
         prg_ins_ge_sol_gesti(r_gsges);
         --
         exception
            when no_data_found then
               null;
            when others then
               raise_application_error(-20000,
               'Act. Solicitud '||sqlerrm);
         END;
      elsif :new.estado IN('R','N','D') then
        IF FUP_OBT_TIP_DESCUENTO(:new.cod_modalidad) IN ('C','D','F') THEN
             BEGIN
                DELETE ge_che_custodias
                 WHERE nro_referencia = :new.nro_solicitud;
             EXCEPTION
                WHEN OTHERS THEN
                   raise_application_error(-20005, 'Error al eliminar ge_che_custodias');
             END;
          END IF;
      end if;
   end if;

   if inserting
   or (updating and
       :new.estado <> :old.estado) then
      --- Actualizar historial de gestiones
      r_psges.nro_solicitud := :new.nro_solicitud;
      r_psges.estado        := :new.estado;
      r_psges.fecha         := sysdate;
      r_psges.cod_usuario   := user;
      r_psges.observacion   := :new.observaciones;
      lp_ins_pr_sol_ges(r_psges);
   end if;
   if updating and :new.estado = 'L' and  :new.estado <> :old.estado then
      -- actualizar campaña si existe a efectivizada
      update cr_cam_personas
         set estado = '4'
       where cod_persona = :new.cod_persona
         and estado = '3'
         and cod_campana = :new.cod_campana;

   end if;
   --AP 2659 Si el estado de la Solicitud cambió de L a S ó de S a R se actualiza la Evaluacion a estado R,
   --para que la solicitud vuelva a ser Evaluada por el Motor de Riesgos
   if updating then
      if (:new.estado = 'S' and :old.estado = 'L') or (:new.estado = 'R' and :old.estado = 'S') then
         if nvl(fug_obt_pardinamico('SOL_MAD_VERIFICACIONES', :new.cod_modulo, :new.cod_modalidad), 'N') = 'S' then
            if fp_ver_dat_rie_evaluaciones(:new.nro_solicitud) then
               update ge_dat_rie_evaluaciones e
                  set e.estado = 'R'
                where e.nro_solicitud = :new.nro_solicitud
                  and e.nro_intento = (select nvl(max(nro_intento), 1)
                                      from ge_dat_rie_evaluaciones
                                     where nro_solicitud = :new.nro_solicitud);
            end if;
         end if;
      end if;
   end if;
   /* Para actualizar el estado de las solicitudes que tiene informe de crédito. */
   if updating then
      if nvl(fug_obt_pardinamico('SOL_INF_CRE_ADMISION', :new.cod_modulo, :new.cod_modalidad), 'N') = 'S' then
          if :new.estado <> :old.estado and :new.estado <> 'S' then
             LP_ACT_GE_INF_CREDITOS('B');
          else if :new.estado <> :old.estado and :new.estado = 'S' then
             LP_ACT_GE_INF_CREDITOS('A');
          end if;
          end if;
       end if;
   end if;
   -- solo para pruebas de circuitos
   /*if inserting then

      v_cod_error := paw_cir.FU_INI_CIRCUITO(2, :new.nro_solicitud, :new.cod_persona); -- 1 es el tipo de circuito
      if v_cod_error <> 0 then
         raise_application_error(-20067,'Error al generar Circuito '||paw_cir.G_MSJ_ERROR);
      end if;

   end if;   */

  -- Cambio solicitado por MIS, la oficina a guardar debe ser la oficina del oficial de la cuenta - RABP 08/10/2013
   if inserting then
      if :new.cod_oficina != FUG_OBT_OFI_OFICIAL(:new.Cod_Persona) then
         raise_application_error(-20000,'La Oficina de la cuenta debe llevar la oficina del Oficial: '||fue_obt_des_oficina(FUG_OBT_OFI_OFICIAL(:new.Cod_Persona))||' ('||FUG_OBT_OFI_OFICIAL(:new.Cod_Persona)||')');
      End If;
   End if;

   /*
   || CROLIANC-4 AT - Liberacion Anticipada Cheques C/O con Creación de Cuentas de Préstamos.
   */
   if updating and :new.estado = 'R' and :old.estado = 'S' and :old.cod_modalidad = 699 then
      update ah_retenciones r
         set r.lib_anticipada = 'N'
       where exists (select 1
                       from cc_lib_ant_cheques a
                      where a.nro_sol_prestamo = :old.nro_solicitud
                        and a.nro_cuenta = r.nro_cuenta
                        and a.nro_documento = r.nro_documento
                        and a.cod_retencion = r.cod_retencion
                        and a.fec_final = r.fec_final);
      Delete from cc_lib_ant_cheques
       where nro_sol_prestamo = :old.nro_solicitud;
   end if;


   --Realizo la carga del perfil del cliente, cuando se dan pre aprobados desde la WEB o MOBILE
   if inserting and :new.usu_insercion = 'HBANK' then
      LP_ACT_PER_CLIENTE;
   end if;

END;
/

