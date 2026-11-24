create or replace function it.fug_tie_per_roles(p_permiso in varchar2, p_cod_rol in varchar2) return varchar2 is
  
  v_tie_permiso varchar2(1) := 'N';
  v_permiso VarChar2(2000) := p_permiso;
  v_lon_permiso Number(10) := nvl(Length(v_permiso),0);
  v_posicion Number(10) := 1;
  v_valor VarChar2(100);
  v_etiqueta VarChar2(1000);

Procedure pr_obt_cod_des_rol 
          (p_cadena In VarChar2,
           p_posicion In Out Number,
           p_valor In Out VarChar2,
           p_etiqueta In Out VarChar2 ) Is
  v_lon_permiso Number(10) := Length(p_cadena);
  v_posicion1 Number(10);
  v_posicion2 Number(10);
Begin
  v_posicion1 := Instr(p_cadena,'-',p_posicion);
  p_valor := Substr(p_cadena,p_posicion,v_posicion1-p_posicion);    
  v_posicion2 := Instr(p_cadena,CHR(243),p_posicion) - 1;  
  If v_posicion2 > 0  Then
    p_etiqueta := LTrim(RTrim(Substr(p_cadena,v_posicion1+1,v_posicion2-v_posicion1-1)));
    p_posicion := v_posicion2+3;
  Else
    p_etiqueta := LTrim(RTrim(Substr(p_cadena,v_posicion1+1,(v_lon_permiso+1)-v_posicion1-1))); 
    p_posicion := v_lon_permiso+1;
  End If;   
  p_etiqueta := nvl(p_etiqueta,' ');
End;
---***

begin
  Loop
    Exit When v_posicion > v_lon_permiso;
    v_valor := Null;
    v_etiqueta := Null;
    -- Obtengo el codigo y descripcion del valor en la cadena  -------
    pr_obt_cod_des_rol(v_permiso,v_posicion,v_valor,v_etiqueta);
    if p_cod_rol = v_valor then --Verificacion si esta incluido el rol--
       v_tie_permiso := 'S';
       exit;
    end if;
  end loop;
  return v_tie_permiso;
exception
  when others then
      raise_application_error(-20001, 'Error en fug_tie_per_roles: '|| SQLERRM);
end;
/

