CREATE OR REPLACE FUNCTION IT.FUA_PUE_REC_CARTON
 (P_COD_OFICINA IN AH_CER_GRUPOS.COD_OFICINA%TYPE, -- oficina del carton
  P_ESTADO      IN AH_CER_GRUPOS.ESTADO%TYPE,       -- estado en el que se recibe
  P_COD_USUARIO IN BA_USUARIOS.COD_USUARIO%TYPE    -- usuario
 )
 RETURN VARCHAR2
 IS
v_puede_recibir varchar2(1) := 'N';
--  Estados posibles
--	A	Activo
--	B	Enviado a B.C.P.
--	E	Entregado
--	N	Anulado
--	R	Suministro
--	S	Solicitado
--	T	Totalmente Utilizado
begin
/*   if p_estado = 'A' then  -- activo
      -- si es el operativo de la agencia, puede recibir como activo
      begin
         select 'S'
           into v_puede_recibir
           from ba_usuarios z, ba_usu_roles x
          where x.cod_usuario = p_cod_usuario
            and (x.cod_rol like '%OPERATIV%' or x.cod_rol like '%RRHH_SUP')
            and z.cod_usuario = x.cod_usuario
            and z.cod_oficina = p_cod_oficina
            and z.estado = 'A' -- activo
            and rownum = 1;
      exception
          when no_data_found then
            v_puede_recibir := 'N';
      end; 
   end if;*/
   if v_puede_recibir = 'N' and p_estado IN ( 'B','R','A') then
      -- SOLO PARA PRUEBA SE HABILITA EL ROL SUMINISTRO
      -- si se esta enviando a BCP, se puede entregar a cualquier usuario
      begin
         select 'S'
           into v_puede_recibir
           from ba_usuarios z, ba_usu_roles x
          where x.cod_usuario = p_cod_usuario
            and x.cod_rol like '%%'  -- cualquier usuario
            and z.cod_usuario = x.cod_usuario
            and z.cod_oficina = p_cod_oficina
            and z.estado = 'A' 
            and rownum = 1;
      exception
          when no_data_found then
            v_puede_recibir := 'N';
      end;      
   end if;  
   if v_puede_recibir = 'N' and p_estado = 'R' then
      -- si se recibe de BCP, se puede entregar solo a suministro
      begin
         select 'S'
           into v_puede_recibir
           from ba_usuarios z, ba_usu_roles x
          where x.cod_usuario = p_cod_usuario
            and x.cod_rol like '%SUMINISTRO%'  -- solo suministro
            and z.cod_usuario = x.cod_usuario
            and z.cod_oficina = p_cod_oficina
            and z.estado = 'A' 
            and rownum = 1;
      exception
          when no_data_found then
            v_puede_recibir := 'N';
      end;      
   end if;
   return v_puede_recibir;
end;
/

