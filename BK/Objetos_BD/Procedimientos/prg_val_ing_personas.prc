CREATE OR REPLACE PROCEDURE IT.PRG_VAL_ING_PERSONAS(p_palabra in varchar2,
                                                    p_tipo    in varchar2,
                                                    p_mensaje out varchar2) is
  V_PALABRA_AUX VARCHAR2(80) := p_palabra;
  v_pos_inicial NUMBER;
  v_POS_FINAL   number;
  v_aux         varchar2(80);
  v_tipo        varchar2(1) := p_tipo; -- 1 direccion 2 telefono
  v_mensaje     varchar2(1000);
  PROCEDURE PRG_VAL_DIR(p_valor varchar2) is
    v_palabra varchar2(80) := p_valor;
    v_inicial varchar2(1);
    v_aux     varchar2(80);
  begin
    v_palabra := replace(v_palabra, ' ', '');
    select substr(v_palabra, 1, 1),
           rpad(substr(v_palabra, 1, 1),
                length(v_palabra),
                substr(v_palabra, 1, 1))
      into v_inicial, v_aux
      from dual;


    if upper(v_aux) = upper(v_palabra) and length(v_palabra) > 1 then
      if v_tipo = 1 then
        v_mensaje := 'Se ha ingresado dirección no válida. Debe ingresar el nombre de la calle principal y una calle secundaria';
      elsif v_tipo =2 then
        v_mensaje:='El teléfono debe tener como mínimo 5 caracteres. El número de teléfono es inválido.';
      end if;

      p_mensaje := v_mensaje;
      if length(p_mensaje)>10 then
                return;
      end if;
    end if;

  end;

begin
  v_pos_inicial := INSTR(V_PALABRA_AUX, ' ', 1);
  V_POS_final   := INSTR(V_PALABRA_AUX, ' ', 1, 2);
  if (substr(v_palabra_aux, nvl(v_POS_inicial,0)+1, 1) is null or nvl(v_pos_inicial,0)=0 ) and v_tipo=1 then
     v_mensaje := 'Se ha ingresado dirección no válida. Debe ingresar el nombre de la calle principal y una calle secundaria';

     p_mensaje := v_mensaje;
     return;
  end if;
  if length(v_palabra_aux)<5 and v_tipo=2 then
     v_mensaje:='El teléfono debe tener como mínimo 5 caracteres. El número de teléfono es inválido.';
      p_mensaje := v_mensaje;
     return;
  end if;

  if nvl(v_pos_inicial, 0) <> nvl(v_pos_final, 0) then
    v_aux := substr(v_palabra_aux, 1, v_pos_inicial - 1);
    PRG_VAL_DIR(v_aux);
    v_palabra_aux := substr(v_palabra_aux,
                            nvl(v_pos_inicial, 0) + 1,
                            length(v_palabra_aux));

  end if;


  WHILE v_palabra_aux is not null LOOP


    v_pos_inicial := INSTR(V_PALABRA_AUX, ' ', 1);

    if nvl(v_pos_inicial, 0) = 0 and v_palabra_aux is not null then
      v_aux := substr(v_palabra_aux, 1, length(v_palabra_aux));
      PRG_VAL_DIR(v_aux);
      v_palabra_aux := null;

    else

      v_aux := substr(v_palabra_aux, 1, v_pos_inicial - 1);
      PRG_VAL_DIR(v_aux);

      v_palabra_aux := substr(v_palabra_aux,
                              v_pos_inicial + 1,
                              length(v_palabra_aux));


    end if;


  END LOOP;
exception
  when others then
    v_mensaje := 'Error de Validacion tipo :' || v_tipo||' - '||sqlerrm;

end;
/

