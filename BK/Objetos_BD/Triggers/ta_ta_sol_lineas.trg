CREATE OR REPLACE TRIGGER IT.TA_TA_SOL_LINEAS
 AFTER DELETE OR INSERT OR UPDATE
 ON TA_SOL_LINEAS
 FOR EACH ROW
DECLARE

  v_act_lin_tarjeta       varchar2(1) := 'N';

  /* Actualiza estado del informe de crédito. */
  PROCEDURE LP_ACT_GE_INF_CREDITOS(P_ESTADO IN VARCHAR2)
   IS
  BEGIN
     UPDATE ge_inf_creditos
        SET estado = p_estado
      WHERE nro_solicitud = :new.nro_solicitud;
  EXCEPTION
    WHEN no_data_found THEN
      NULL;
    WHEN OTHERS THEN
      raise_application_error(-20000, 'Act. Informe Crédito. ' || SQLERRM);
  END;

BEGIN
   /* Para actualizar el estado de las solicitudes que tiene informe de crédito. */
  IF updating THEN
     IF :new.tip_solicitud = 'A' THEN
        pag_cta.pr_obt_cuenta(:new.nro_cuenta);
        IF NVL(fug_obt_pardinamico('SOL_INF_CRE_ADMISION', pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad), 'N') = 'S' THEN
           IF :new.cod_estado <> :old.cod_estado AND :new.cod_estado <> 'PAN' THEN
              LP_ACT_GE_INF_CREDITOS('B');
           ELSIF :new.cod_estado <> :old.cod_estado AND :new.cod_estado = 'PAN' THEN
              LP_ACT_GE_INF_CREDITOS('A');
           END IF;
        END IF;
        IF :old.cod_estado <> 'APR' and :new.cod_estado = 'APR' THEN
           v_act_lin_tarjeta := 'S';
        END IF;
     END IF;
  ELSIF inserting THEN
     IF :new.tip_solicitud = 'A' THEN
        IF :new.cod_estado = 'APR' THEN
           v_act_lin_tarjeta := 'S';
        END IF;
     END IF;
     IF :new.tip_solicitud = 'D' THEN
        IF :new.cod_estado = 'APR' THEN
           v_act_lin_tarjeta := 'S';
        END IF;
     END IF;
  END IF;
  -- Actualiza la línea de la Tarjeta
  IF v_act_lin_tarjeta = 'S' THEN
     BEGIN
       UPDATE ta_cta_tarjetas
          SET lin_credito = :new.lin_credito
        WHERE nro_cuenta  = :new.nro_cuenta;
     END;
  END IF;
END;
/

