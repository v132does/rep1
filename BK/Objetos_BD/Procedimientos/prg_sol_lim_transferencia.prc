create or replace procedure it.prg_sol_lim_transferencia(p_cod_persona in ba_personas.cod_persona%type,
                                                         p_nro_cuenta  in ge_cuentas.nro_cuenta%type,
                                                         p_cod_moneda  in ge_cuentas.cod_moneda%type,
                                                         p_monto       in number,
                                                         p_cod_error   out number,
                                                         p_mensaje     out varchar2) is
  --definicion de variables
  v_tipo        varchar2(1);
  v_hora_desde  varchar2(10) := fug_obt_pardinamico('MIN_HOR_SOL_AUM_LIM_TRA_SIPAP');
  v_hora_hasta  varchar2(10) := fug_obt_pardinamico('MAX_HOR_SOL_AUM_LIM_TRA_SIPAP');
  v_hora_actual varchar2(10) := to_char(sysdate, 'HH24:MI');
  v_tie_gen_wf  VARCHAR2(1) := 'N';
  v_comentario  wf_cir_tareas.comentario%TYPE;
begin
  IF p_cod_persona is null THEN
    p_cod_error := 4;
    p_mensaje   := 'La persona no puede ser nula';
  ELSE
    BEGIN
      select tipo
        into v_tipo
        from ba_personas
       where cod_persona = p_cod_persona;
    EXCEPTION
      WHEN no_data_found THEN
        p_cod_error := 12;
        p_mensaje   := 'Persona no definida en el sistema.';
      WHEN too_many_rows THEN
        select tipo
          into v_tipo
          from ba_personas
         where cod_persona = p_cod_persona
           and rownum = 1;
      WHEN OTHERS THEN
        p_cod_error := 13;
        p_mensaje   := 'Ocurrio un error. ' || SQLERRM;
    END;
  END IF;
  --
  IF nvl(p_cod_error, 0) = 0 THEN
    --
    IF p_cod_moneda is null THEN
      p_cod_error := 4;
      p_mensaje   := 'La moneda no puede ser nula';
    ELSIF p_cod_moneda not in ('GS', 'USD') THEN
      p_cod_error := 4;
      p_mensaje   := 'La moneda debe ser GS o USD';
    END IF;
    --
    IF nvl(p_cod_error, 0) = 0 THEN
      IF v_hora_actual < v_hora_desde or v_hora_actual > v_hora_hasta THEN
        p_cod_error := 1;
        p_mensaje   := 'Este pedido se puede procesar desde las ' ||
                       v_hora_desde || ' hs hasta ' || v_hora_hasta ||
                       'hs.';
      END IF;
      --
      IF nvl(p_cod_error, 0) = 0 THEN
        BEGIN
          SELECT 'S'
            INTO v_tie_gen_wf
            FROM wf_circuitos a
           WHERE a.cod_tip_circuito = 2
             AND a.cod_persona = p_cod_persona
             AND a.estado in ('E', 'F', 'C')
             AND trunc(a.fec_inicio) = trunc(sysdate);
        EXCEPTION
          WHEN no_data_found THEN
            v_tie_gen_wf := 'N';
          WHEN too_many_rows THEN
            SELECT 'S'
              INTO v_tie_gen_wf
              FROM wf_circuitos a
             WHERE a.cod_tip_circuito = 2
               AND a.cod_persona = p_cod_persona
               AND a.estado in ('E', 'F', 'C')
               AND trunc(a.fec_inicio) = trunc(sysdate)
               AND rownum = 1;
          WHEN OTHERS THEN
            v_tie_gen_wf := 'N';
        END;
        --
        IF v_tie_gen_wf = 'S' THEN
          p_cod_error := 2;
          p_mensaje   := 'Solo se puede realizar una solicitud por día';
        ELSE
          IF v_tipo = 'F' THEN
            IF p_nro_cuenta is null THEN
              /*p_cod_error := 4;
              p_mensaje   := 'El nro. de cuenta para una persona física no puede ser nulo.';*/
             v_comentario := 'Cod. persona: ' || p_cod_persona ||
                            '; Moneda: ' || p_cod_moneda ||
                            '; Monto a sumar al límite actual: ' || p_monto;
                IF paw_cir.FU_INI_CIRCUITO(2,
                                           p_cod_persona,
                                           p_cod_persona,
                                           v_comentario) <> 0 THEN
                  p_cod_error := 3;
                  p_mensaje   := 'En este momento no es posible realizar la solicitud. Por favor, intente más tarde';
                ELSE
                  p_cod_error := 0;
                  p_mensaje   := 'Su solicitud ha sido registrada con éxito. ¡En breve nos comunicamos con usted!';
                END IF;
            ELSE
              v_comentario := 'Cod. persona: ' || p_cod_persona ||
                              '; Nro. Cuenta: ' || p_nro_cuenta ||
                              '; Moneda: ' || p_cod_moneda ||
                              '; Monto a sumar al límite actual: ' ||
                              p_monto;
              --
              IF paw_cir.FU_INI_CIRCUITO(2,
                                         p_nro_cuenta,
                                         p_cod_persona,
                                         v_comentario) <> 0 THEN
                p_cod_error := 3;
                p_mensaje   := 'En este momento no es posible realizar la solicitud. Por favor, intente más tarde';
              ELSE
                p_cod_error := 0;
                p_mensaje   := 'Su solicitud ha sido registrada con éxito. ¡En breve nos comunicamos con usted!';
              END IF;
            END IF;
          ELSE
            v_comentario := 'Cod. persona: ' || p_cod_persona ||
                            '; Moneda: ' || p_cod_moneda ||
                            '; Monto a sumar al límite actual: ' || p_monto;
            IF paw_cir.FU_INI_CIRCUITO(2,
                                       p_cod_persona,
                                       p_cod_persona,
                                       v_comentario) <> 0 THEN
              p_cod_error := 3;
              p_mensaje   := 'En este momento no es posible realizar la solicitud. Por favor, intente más tarde';
            ELSE
              p_cod_error := 0;
              p_mensaje   := 'Su solicitud ha sido registrada con éxito. ¡En breve nos comunicamos con usted!';
            END IF;
          END IF;
        END IF;
      END IF;
    END IF;
  END IF;
  --
exception
  when others then
    p_cod_error := 999;
    p_mensaje   := 'Error en proceso prg_sol_lim_transferencia ' || ' - ' ||
                   sqlerrm;
end;
/

