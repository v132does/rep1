CREATE OR REPLACE FUNCTION IT.FUP_OBT_ORI_FON_MODALIDAD
          (p_modalidad pr_cta_prestamos.cod_modalidad%TYPE,
           p_moneda    pr_cta_prestamos.cod_moneda%TYPE)
  return number is
  v_ori_fondo   pr_fondos.cod_ori_fondo%type;
  v_modalidades pr_fondos.par_modalidad%type;
  v_pos number;
  v_fin number;
  v_str varchar2(4000);
  cursor c_modalidades is
  select f.cod_ori_fondo, f.par_modalidad
  from   pr_fondos f
  where  f.par_modalidad is not null and
         f.cod_moneda = p_moneda;        ----- agregado para que tenga en cuenta la moneda y modalidad    DM  06/01/2010
begin
  for r_fond in c_modalidades loop
    v_ori_fondo := 0;
    v_pos := 1;
    v_fin := 0;
    v_modalidades := r_fond.par_modalidad;
    --dbms_output.put_line('v_modalidades ' || v_modalidades);
     while v_pos > 0 loop
      v_pos := INSTR(v_modalidades, ',', 1, 1);
      if v_pos > 0 then
        v_fin := v_pos - 1;
      else
        v_fin := length(v_modalidades);
        v_pos := 0;
      end if;
      v_str := substr(v_modalidades,1,v_fin);
      if p_modalidad = v_str then
         v_ori_fondo := r_fond.cod_ori_fondo;
         Return v_ori_fondo;
      end if;
      --dbms_output.put_line('v_fin: ' || to_char(v_fin) || ' | v_pos: ' || to_char(v_pos));
      --dbms_output.put_line('p_modalidad: ' || to_char(p_modalidad) || ' | v_str ' || v_str);
      --dbms_output.put_line('---------------------------');
      v_modalidades := substr(v_modalidades,v_pos + 1);
      --dbms_output.put_line('v_modalidades ' || v_modalidades);
    end loop;
  end loop;
  Return v_ori_fondo;

end FUP_OBT_ORI_FON_MODALIDAD;
/

