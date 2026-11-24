create or replace function it.fug_ver_ope_clave_mas
(
   p_cod_persona       in ba_personas.cod_persona%type,
   p_tip_clave         in bw_ope_claves.tip_clave%type
) return varchar2 is
   v_existe varchar2(1) := 'N';
   v_existe_1 varchar2(1) := 'N';
   v_existe_2 varchar2(1) := 'N';
   v_existe_3 varchar2(1) := 'N';
   v_plazo  number := FUG_OBT_PARDINAMICO('FEC_MESES_CLA');
   v_fec_actual    date := pag_cal.fu_obt_fec_actual(1) ; 
begin
   
     begin
      select 'S'
        into v_existe
        from bw_ope_claves
       where cod_persona = p_cod_persona
         and tip_clave = p_tip_clave ;
      exception
        when no_data_found then 
           v_existe := 'N' ; 
        when others then
           v_existe := 'X' ; 
       
      end ;
     if v_existe = 'S' then 
           begin
            select 'S'
              into v_existe_1
              from bw_ope_claves v
             where cod_persona = p_cod_persona
               and tip_clave = p_tip_clave
               and est_clave = 'M'
               and (v_fec_actual - v.fec_ult_acceso) > v_plazo ;
            exception
              when others then
                v_existe_1 := 'N' ;
            end ;
           begin
            select 'S'
              into v_existe_2
              from bw_ope_claves
             where cod_persona = p_cod_persona
               and est_clave = 'A'
               and tip_clave = p_tip_clave;
           exception
              when others then
                 v_existe_2 := 'N' ;  
           end ;
           begin
            select 'S'
              into v_existe_3
              from bw_ope_claves
             where cod_persona = p_cod_persona
               and est_clave in ('B', 'X')
               and tip_clave = p_tip_clave;
            exception
              when others then
                 v_existe_3 := 'N' ;  
            end ;
            if v_existe_1 = 'S' or v_existe_2 = 'S' or v_existe_3 = 'S' then
               v_existe := 'N' ;
            else
               v_existe := 'S' ;
            end if ;
       end if ;
   return v_existe ;
   
exception
   when no_data_found then
      null ;
   when others then
      raise_application_error(-20000, 'error en fug_ver_ope_clave_mas. ' || sqlerrm);
end;
/

