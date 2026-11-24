CREATE OR REPLACE PROCEDURE IT.PRG_INS_REG_DUOCARD(p_cod_persona   BA_PER_DUOCARD_REGISTRO.COD_PERSONA%type,
                                                   p_col_tarjeta   BA_PER_DUOCARD_REGISTRO.COL_TARJETA%type,
                                                   p_estado        BA_PER_DUOCARD_REGISTRO.ESTADO%type,
                                                   p_origen        varchar2 default null,
                                                   p_cod_respuesta out number,
                                                   p_msj_respuesta out varchar2) IS
  v_cod_error   number;
  v_msj_error   varchar2(200);
  v_cod_persona ba_personas.cod_persona%type;
  v_significado ba_cod_referencias.significado%type;
BEGIN
  --Validar los campos de entrada
  if p_cod_persona is null then
    v_cod_error := 1;
    v_msj_error := 'Codigo de persona nulo';
  end if;
  if p_col_tarjeta is null then
    v_cod_error := 2;
    v_msj_error := 'Color de tarjeta nulo';
  end if;
  if p_estado is null then
    v_cod_error := 3;
    v_msj_error := 'Estado nulo';
  end if;
  if p_origen is null then
    v_cod_error := 4;
    v_msj_error := 'Origen nulo';
  end if;

  begin
    select cod_persona
      into v_cod_persona
      from ba_personas t
     where t.cod_persona = p_cod_persona;
  exception
    when no_data_found then
      v_cod_error := 5;
      v_msj_error := 'Persona no existe';
      prg_ins_log_programas('PRG_INS_REG_DUOCARD', substr('Cod_Error. ' || v_cod_error ||
                            ' Error: ' || v_msj_error || ' ' || dbms_utility.format_error_stack || ' - ' ||
                            dbms_utility.format_error_backtrace, 1, 4000), p_cod_persona, null);
  end;
 /* begin
    Select t.significado
      into v_significado
      from ba_cod_referencias t
     where t.dominio = 'COL_TARJETAS'
       and trim(t.significado) = trim(p_col_tarjeta);
  exception
    when no_data_found then
      v_cod_error := 6;
      v_msj_error := 'Color Incorrecto';
      prg_ins_log_programas('PRG_INS_REG_DUOCARD', substr('Cod_Error. ' || v_cod_error ||
                            ' Error: ' || v_msj_error || ' ' || dbms_utility.format_error_stack || ' - ' ||
                             dbms_utility.format_error_backtrace, 1, 4000), p_cod_persona, null);
  end;*/

  if nvl(v_cod_error, 0) = 0 then
    begin
      insert into BA_PER_DUOCARD_REGISTRO
        (COD_PERSONA, COL_TARJETA, ESTADO, ORIGEN)
      values
        (p_cod_persona, p_col_tarjeta, p_estado, p_origen);
      commit;
    exception
      when others then
        v_cod_error := 5;
        v_msj_error := 'Error al insertar.';
        prg_ins_log_programas('PRG_INS_REG_DUOCARD', substr('Cod_Error. ' || v_cod_error ||
                              ' Error: ' || v_msj_error || ' ' || dbms_utility.format_error_stack || ' - ' ||
                              dbms_utility.format_error_backtrace, 1, 4000), p_cod_persona, null);
    end;
  end if;
  if nvl(v_cod_error, 0) != 0 then
    p_cod_respuesta := v_cod_error;
    p_msj_respuesta := v_msj_error;
        prg_ins_log_programas('PRG_INS_REG_DUOCARD', substr('Cod_Error. ' || v_cod_error ||
                              ' Error: ' || v_msj_error || ' ' || dbms_utility.format_error_stack || ' - ' ||
                              dbms_utility.format_error_backtrace, 1, 4000), p_cod_persona, null);
  else
    p_cod_respuesta := 0;
    p_msj_respuesta := 'OK';
  end if;
EXCEPTION
  when others then
        prg_ins_log_programas('PRG_INS_REG_DUOCARD', substr('Cod_Error. ' || v_cod_error ||
                              ' Error: ' || v_msj_error || ' ' || dbms_utility.format_error_stack || ' - ' ||
                              dbms_utility.format_error_backtrace, 1, 4000), p_cod_persona, null);
END;
/
