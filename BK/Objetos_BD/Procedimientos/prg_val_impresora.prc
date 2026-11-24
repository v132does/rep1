create or replace procedure it.prg_val_impresora(p_pue_imprimir out varchar2,
                                                 p_mensaje out varchar2) is
  --Variables--
  v_cad_ver_imp_pines ge_par_dinamicos.val_parametro%type;
  v_desde number(4);
  v_hasta number(4);
  v_puntero number(4);
  v_cadena ge_par_dinamicos.val_parametro%type;
  v_len_cadena number(4);
  v_imp_por_defecto ge_ver_impresoras_tmp.texto%type;
  
begin
  p_pue_imprimir := 'S';
  p_mensaje := null;
  
  begin 
  SELECT upper(substr(y.texto,instr(y.texto,'defecto')+9))
    into v_imp_por_defecto
    FROM GE_VER_IMPRESORAS_TMP Y
    WHERE upper(y.texto) like '%IMPRESORA POR DEFECTO:=%'
      AND Y.USU_INSERCION = USER; --Validacion del ususuario--
  exception 
    when too_many_rows then 
      p_pue_imprimir := 'N';
      p_mensaje := 'Error tiene varias impresoras por defecto. Verifique';
    when no_data_found then 
      p_pue_imprimir := 'N';
      p_mensaje := 'La PC no tiene impresora por defecto. Verifique.';      
    when others then 
      p_pue_imprimir := 'N';
      p_mensaje := 'Error en programa de verificacion de impresora.';
  end;
  
  if instr(v_imp_por_defecto,'NINGUN') > 0 then
     p_pue_imprimir := 'N';
     p_mensaje := 'La PC no tiene impresora por defecto. Verifique.';   
  ELSE
      if p_pue_imprimir = 'S' then
          v_cad_ver_imp_pines := fug_obt_pardinamico('CAD_VER_IMP_PINES');
          --dbms_output.put_line('Parametro: '||v_cad_ver_imp_pines||' Impresora :'||v_imp_por_defecto);
          if v_cad_ver_imp_pines is not null then
              v_puntero := 1;
              LOOP
                  if substr(v_cad_ver_imp_pines,v_puntero,1) = ',' then
                     v_desde := instr(v_cad_ver_imp_pines,',',v_puntero);
                  else
                     v_desde := 0;
                  end if;
                  v_hasta := instr(v_cad_ver_imp_pines,',',v_desde+1);
                  if v_hasta <> 0 then
                     v_cadena := upper(substr(v_cad_ver_imp_pines,v_desde+1,(v_hasta-v_desde)-1));
                     --dbms_output.put_line('Desde: '||to_char(v_desde)||' Hasta: '||to_char(v_hasta)||' Texto: '||v_cadena);
                     v_puntero := nvl(v_hasta,0);
                     if instr(v_imp_por_defecto,v_cadena) > 0 then
                        p_pue_imprimir := 'N';
                        p_mensaje := 'La impresora por defecto no es valida. Verifique.';
                     end if;
                  else
                     v_len_cadena := length(v_cad_ver_imp_pines);
                     if v_desde < v_len_cadena then
                        v_cadena := upper(substr(v_cad_ver_imp_pines,v_desde+1,(v_len_cadena-v_desde)));
                        --dbms_output.put_line('Desde: '||to_char(v_desde)||' Hasta: '||to_char(v_len_cadena)||' Texto: '||v_cadena);
                        if instr(v_imp_por_defecto,v_cadena) > 0 then
                           p_pue_imprimir := 'N';
                           p_mensaje := 'La impresora por defecto no es valida. Verifique.';
                        end if;
                     end if;
                  end if;
                  EXIT WHEN v_hasta = 0;
              END LOOP;
          end if;
       else
          --si no tiene impresora por defecto--
          p_pue_imprimir := 'N';
          p_mensaje := 'La PC no tiene impresora por defecto. Verifique.';
       end if;
   END IF;
end;
/

