create or replace procedure it.pre_obt_ciu_pais
 ( P_cod_persona in ba_personas.cod_persona%TYPE
  ,p_cod_pais   OUT ba_paises.COD_pais%TYPE
  ,p_des_pais   OUT ba_paises.descripcion%TYPE
  ,p_cod_ciudad OUT ba_ciudades.COD_ciudad%TYPE
  ,p_des_ciudad OUT ba_ciudades.descripcion%TYPE)
   is
-- recupero la ciudad y el país de la dirección
begin
   select c.cod_pais, c.descripcion, a.cod_ciudad, a.descripcion
			into p_cod_pais, p_des_pais, p_cod_ciudad, p_des_ciudad
   from ba_ciudades a, ba_direcciones b, ba_paises c
   where a.cod_ciudad = b.cod_ciudad
   and a.cod_pais = b.cod_pais
   and b.cod_pais = c.cod_pais
   and b.cod_persona = p_cod_persona
   and b.principal = 'S';

exception
  when no_data_found then
     null;
  when others then
     raise_application_error(-20000,'Recup.Ciudad/País.'||sqlerrm);
end;
/

