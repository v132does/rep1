create or replace function it.FUP_VER_ORI_FON_MODALIDAD
          (p_modalidades pr_fondos.par_modalidad%type)
  return number is
  v_modalidades pr_fondos.par_modalidad%type;
  v_pos number;
  v_fin number;
  v_str varchar2(4000);
  v_modalidad pr_cta_prestamos.cod_modalidad%type;
  v_existe number := 0;
begin
  v_modalidades := p_modalidades;
  v_pos := 1;
  v_fin := 0;
  dbms_output.put_line('v_modalidades ' || v_modalidades);
  while v_pos > 0 loop
    v_pos := INSTR(v_modalidades, ',', 1, 1);
    if v_pos > 0 then
      v_fin := v_pos - 1;
    else
      v_fin := length(v_modalidades);
      v_pos := 0;
    end if;
    v_str := substr(v_modalidades,1,v_fin);
    v_modalidad := to_number(v_str);
    ---
    --dbms_output.put_line('v_fin: ' || to_char(v_fin) || ' | v_pos: ' || to_char(v_pos));
    --dbms_output.put_line('p_modalidades: ' || to_char(p_modalidades) || ' | v_str ' || v_str);
    --dbms_output.put_line('---------------------------');
    --dbms_output.put_line('v_modalidad ' || v_modalidad);
    --- validar la modalidad no sea tipo descuento de documentos
    --- se copio el LOV del form EPPROCOR para la validación
    begin
      select 1
      into   v_existe
      from   GE_MODALIDADES
      where  COD_MODULO = 6
      and    cod_modalidad not in (62,608,620, 630)
      AND    FUG_OBT_PARDINAMICO('MOD_PRE_CORPORATIVOS', COD_MODULO, COD_MODALIDAD, NULL, NULL) = 'S'
      and    cod_modalidad = v_modalidad
      order  by COD_MODALIDAD;
    exception
      when no_data_found then
        v_existe := 0;
    end;
    ---
    --dbms_output.put_line('v_existe: ' || to_char(v_existe));
    if v_existe = 0 then
       Return v_existe;
    end if;
    v_modalidades := substr(v_modalidades,v_pos + 1);
    --dbms_output.put_line('v_modalidades ' || v_modalidades);
  end loop;
  Return v_existe;

end FUP_VER_ORI_FON_MODALIDAD;
/

