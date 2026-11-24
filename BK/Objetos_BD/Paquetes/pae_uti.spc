CREATE OR REPLACE PACKAGE IT.PAE_UTI IS
function FU_OBT_POSICION(p_cadena in varchar2,
                         p_valor in varchar2)
  return number;
function FU_OBT_VALOR(p_registro in varchar2,
                      p_nro_secuencia in number)
  return varchar2;
function fu_por_igu_textos(p_texto1 in varchar2,
                           p_texto2 in varchar2,
                           p_may_sensible in varchar2,
                           p_modo in varchar2)
return number;
--Para Montos Acorde a Definición de Usuario
function FU_OBT_MONTO(p_dato in varchar2)
  return varchar2;

-- Para obtener valor especificando el separador de campos --
function FU_OBT_VALOR( p_registro in varchar2,
                       p_nro_secuencia in number,
                       p_separador in varchar2 )
  return varchar2;

  
END PAE_UTI;
/

