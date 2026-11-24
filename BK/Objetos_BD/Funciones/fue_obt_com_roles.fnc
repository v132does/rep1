create or replace function it.fue_obt_com_roles (p_cadena1 in varchar2,p_cadena2 in varchar2 )
   return varchar2 is
   v_return char(1) ;
begin   
    Select decode(count(*),0,'N','S')
         into v_return
      from (select distinct r.cod_rol
              from ba_roles r
             where exists
             (select 1 from dual where instr(p_cadena1, r.cod_rol) > 0)
               and r.cod_rol not in
                   (select distinct r.cod_rol
                      from ba_roles r
                     where exists
                     (select 1
                              from dual
                             where instr(p_cadena2, r.cod_rol) > 0))
            union
            select distinct r.cod_rol
              from ba_roles r
             where exists
             (select 1
                      from dual
                     where instr(p_cadena2, r.cod_rol) > 0)
               and r.cod_rol not in
                   (select distinct r.cod_rol
                      from ba_roles r
                     where exists
                     (select 1
                              from dual
                             where instr(p_cadena1, r.cod_rol) > 0)));

   return v_return ;
exception
   when others then
        return 'N';        
end;
/

