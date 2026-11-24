create or replace function it.FUG_ES_EMPLEADO(p_cod_persona varchar2) return varchar2 is
  v_existe varchar2(1) := 'N';
  v_cod_segmento ge_clientes.cod_seg_cliente%type;
begin
     begin
       Select 'S'
         into v_existe
         from ba_usuarios
        where cod_persona = p_cod_persona
          and estado = 'A';
     exception
         When NO_DATA_FOUND Then
              v_existe := 'N';
         When TOO_MANY_ROWS Then
              v_existe := 'S';
     end;
     if v_existe = 'N' then
         select cod_seg_cliente
           into v_cod_segmento
           from ge_clientes
          where cod_persona = p_cod_persona;
        if v_cod_segmento = fug_obt_pardinamico('SEG_FUNCIONARIOS') then -- funcionarios
           v_existe := 'S';
        else
           v_existe := 'N';
        end if;
     end if;
     Return v_existe;
Exception
     When NO_DATA_FOUND Then
          v_existe := 'N';
          return(v_existe);
     When others then
          v_existe := 'N';
          return(v_existe);
end fug_es_empleado;
/

