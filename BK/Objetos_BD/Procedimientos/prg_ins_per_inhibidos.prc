CREATE OR REPLACE PROCEDURE IT.PRG_INS_PER_INHIBIDOS
 (p_fecha IN DATE
 ,p_cod_usuario in varchar2
 ,p_cod_persona in varchar2
 ,p_cod_causa in number
 ,p_origen    in varchar2
 ,p_detalle   in varchar2
 ,p_estado    in varchar2
)
 IS
 v_cant number;
 v_nro_orden number;
BEGIN
  BEGIN
    v_cant:=0;

    select count(*) 
      into v_cant  
      from ge_per_inhibidas t
     where t.cod_persona= p_cod_persona
       and t.cod_causa=p_cod_causa;
  END;  
  if nvl(v_cant,0) = 0 then
    BEGIN
      v_nro_orden := 0;
      select nvl(max(t.nro_orden) ,0) + 1
        into v_nro_orden  
        from ge_per_inhibidas t
       where t.cod_persona= p_cod_persona;
    END;  
    BEGIN
      insert into ge_per_inhibidas 
         (cod_persona,nro_orden, cod_causa,  fec_inicio, origen, detalle, estado  )  
      values
         (p_cod_persona,v_nro_orden,p_cod_causa,p_fecha,p_origen,p_detalle,p_estado);
    END;    
  end if;  
exception
  when others then
     raise_application_error(-20000,'ge_per_inhibidas '||sqlerrm);
END;
/

